import SwiftUI
import Foundation

/// Drives the Apple Fitness style calendar.
/// All progress is derived in memory from tasks + task completions, so switching
/// filter (personal / shared / both) or period never needs another network call
/// and never loses data. Completions are never deleted, which is what keeps
/// weekly / monthly / quarterly / yearly history available after a task's
/// deserving cycle resets.
@MainActor
class CalendarViewModel: ObservableObject {
    enum FilterMode: CaseIterable, Hashable {
        case personal, shared, both
        
        var label: String {
            switch self {
            case .personal: return "Personal Goals"
            case .shared: return "Shared Goals"
            case .both: return "All Goals"
            }
        }
        var includesPersonal: Bool { self != .shared }
        var includesShared: Bool { self != .personal }
    }
    
    enum TimePeriod: CaseIterable, Hashable {
        case weekly, monthly, quarterly, yearly
        
        var label: String {
            switch self {
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            case .quarterly: return "Quarterly"
            case .yearly: return "Yearly"
            }
        }
    }
    
    /// Totals shown in the summary header for the visible period
    struct PeriodTotals {
        var personal: Double?
        var shared: Double?
        var combined: Double?
        var done: Double = 0
        var total: Int = 0
        var perfectDays: Int = 0
    }
    
    // MARK: - Published state
    
    @Published var selectedMonth: Date = Date()          // anchor date of the visible period
    @Published var filterMode: FilterMode = .personal    // default: personal goals only
    @Published var selectedPeriod: TimePeriod = .monthly
    
    @Published private(set) var calendarDays: [CalendarDayProgress] = []   // filtered days for weekly / monthly
    @Published private(set) var leadingBlankDays = 0                       // aligns day 1 under its weekday
    @Published private(set) var monthTiles: [MonthTile] = []               // quarterly / yearly
    @Published private(set) var taskSummaries: [TaskPeriodSummary] = []
    @Published private(set) var totals = PeriodTotals()
    @Published private(set) var claimedDeservings: [ClaimedDeserving] = []
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var hasDataGaps = false      // some completions failed to load
    @Published private(set) var incompleteMonth = false  // visible period still in progress
    
    var firebaseService: FirebaseService
    var taskViewModel: TaskViewModel
    
    // MARK: - Source data
    
    private var calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 1   // Sunday, matches the S M T W T F S header
        return cal
    }()
    private let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private var tasks: [Task] = []
    private var memberIds: [String] = []
    private var currentPigeonId = ""
    private var doneDates: [String: [String: Set<String>]] = [:]   // taskId -> pigeonId -> completed dates
    private var allDays: [Date: CalendarDayProgress] = [:]         // unfiltered cache by start of day
    
    /// Injectable clock so period logic can be tested on fixed dates
    private let now: () -> Date
    
    init(firebaseService: FirebaseService, taskViewModel: TaskViewModel, now: @escaping () -> Date = { Date() }, autoLoad: Bool = true) {
        self.firebaseService = firebaseService
        self.taskViewModel = taskViewModel
        self.now = now
        self.selectedMonth = now()
        keyFormatter.calendar = calendar
        if autoLoad {
            _Concurrency.Task { await loadCalendarData() }
        }
    }
    
    // MARK: - Loading
    
    func loadCalendarData() async {
        errorMessage = nil
        hasDataGaps = false
        
        // Edge case: user has no nest / profile yet
        guard let nest = firebaseService.currentNest, let me = firebaseService.currentPigeon else {
            errorMessage = "Join a nest to see your calendar."
            rebuild()
            return
        }
        isLoading = true
        defer { isLoading = false }
        
        if taskViewModel.tasks.isEmpty {
            await taskViewModel.fetchTasks(nestId: nest.id)
        }
        tasks = taskViewModel.tasks
        memberIds = nest.pigeons
        currentPigeonId = me.id
        doneDates = [:]
        
        var failedFetches = 0
        for task in tasks {
            for pigeonId in participants(of: task) {
                if let completions = await firebaseService.fetchCompletions(taskId: task.id, pigeonId: pigeonId) {
                    doneDates[task.id, default: [:]][pigeonId] = Set(completions.filter { $0.isComplete }.map { $0.date })
                } else {
                    failedFetches += 1
                }
            }
        }
        if failedFetches > 0 {
            hasDataGaps = true
            errorMessage = "Some check-ins couldn't be loaded. Progress may look lower than it is."
        }
        
        claimedDeservings = await firebaseService.fetchClaimedDeservings(pigeonId: me.id) ?? []
        rebuild()
    }
    
    /// Who must check in for this task: only the owner for personal tasks, every nest member for shared ones
    private func participants(of task: Task) -> [String] {
        switch task.taskType {
        case .personal: return task.createdBy == currentPigeonId ? [currentPigeonId] : []
        case .shared: return memberIds.isEmpty ? [currentPigeonId] : memberIds
        }
    }
    
    // MARK: - Per-day calculation
    
    private func key(_ date: Date) -> String { keyFormatter.string(from: date) }
    
    /// Edge cases: a task doesn't exist before it was created, and a weekly task is due on one weekday only
    private func isScheduled(_ task: Task, on day: Date) -> Bool {
        let created = calendar.startOfDay(for: task.createdAt)
        guard day >= created else { return false }
        switch task.frequency {
        case .daily, .custom: return true
        case .weekly: return calendar.component(.weekday, from: day) == calendar.component(.weekday, from: created)
        }
    }
    
    /// Shared tasks give partial credit while only one partner has checked in
    private func credit(_ task: Task, on key: String) -> Double {
        let people = participants(of: task)
        guard !people.isEmpty else { return 0 }
        let done = people.filter { doneDates[task.id]?[$0]?.contains(key) == true }.count
        return Double(done) / Double(people.count)
    }
    
    private func rawDay(_ date: Date) -> CalendarDayProgress {
        let day = calendar.startOfDay(for: date)
        if let cached = allDays[day] { return cached }
        
        let isFuture = day > calendar.startOfDay(for: now())
        let dayKey = key(day)
        var progress = CalendarDayProgress(
            id: dayKey,
            date: day,
            dayOfWeek: calendar.component(.weekday, from: day),
            dayOfMonth: calendar.component(.day, from: day)
        )
        progress.isFuture = isFuture
        
        for task in tasks where isScheduled(task, on: day) {
            if task.taskType == .personal && task.createdBy != currentPigeonId { continue }
            let earned = isFuture ? 0 : credit(task, on: dayKey)
            if task.taskType == .personal {
                progress.personalScheduled += 1
                progress.personalDone += earned
            } else {
                progress.sharedScheduled += 1
                progress.sharedDone += earned
            }
        }
        
        for claim in claimedDeservings where claim.dateClaimedString == dayKey {
            if claim.taskType == .personal { progress.personalCheckpointsClaimed += 1 }
            else { progress.sharedCheckpointsClaimed += 1 }
        }
        allDays[day] = progress
        return progress
    }
    
    private func filteredDay(_ date: Date) -> CalendarDayProgress {
        rawDay(date).filtered(includePersonal: filterMode.includesPersonal, includeShared: filterMode.includesShared)
    }
    
    // MARK: - Period ranges
    
    /// Inclusive start and exclusive end of the visible period
    private func range(for period: TimePeriod, anchor: Date) -> DateInterval {
        switch period {
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: anchor) ?? DateInterval(start: anchor, duration: 7 * 86_400)
        case .monthly:
            return calendar.dateInterval(of: .month, for: anchor) ?? DateInterval(start: anchor, duration: 30 * 86_400)
        case .quarterly:
            let comps = calendar.dateComponents([.year, .month], from: anchor)
            let firstMonth = ((comps.month ?? 1) - 1) / 3 * 3 + 1
            let start = calendar.date(from: DateComponents(year: comps.year, month: firstMonth, day: 1)) ?? anchor
            let end = calendar.date(byAdding: .month, value: 3, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .yearly:
            return calendar.dateInterval(of: .year, for: anchor) ?? DateInterval(start: anchor, duration: 365 * 86_400)
        }
    }
    
    private func days(in interval: DateInterval) -> [Date] {
        var result: [Date] = []
        var cursor = calendar.startOfDay(for: interval.start)
        while cursor < interval.end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }
    
    private var earliestTaskDay: Date? {
        tasks.map { calendar.startOfDay(for: $0.createdAt) }.min()
    }
    
    // MARK: - Rebuild (filter-aware)
    
    private func rebuild() {
        allDays = [:]
        let interval = range(for: selectedPeriod, anchor: selectedMonth)
        let today = calendar.startOfDay(for: now())
        let periodDays = days(in: interval)
        
        switch selectedPeriod {
        case .weekly, .monthly:
            calendarDays = periodDays.map(filteredDay)
            monthTiles = []
            leadingBlankDays = selectedPeriod == .monthly
                ? (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
                : 0
        case .quarterly, .yearly:
            calendarDays = []
            leadingBlankDays = 0
            monthTiles = buildMonthTiles(in: interval)
        }
        
        // Totals over tracked (scheduled, non-future) days only
        var t = PeriodTotals()
        var pDone = 0.0, pTotal = 0, sDone = 0.0, sTotal = 0
        for day in periodDays {
            let d = filteredDay(day)
            guard !d.isFuture, !d.hasNoData else { continue }
            pDone += d.personalDone; pTotal += d.personalScheduled
            sDone += d.sharedDone; sTotal += d.sharedScheduled
            if d.combinedProgress >= 1 { t.perfectDays += 1 }
        }
        t.personal = pTotal > 0 ? pDone / Double(pTotal) : nil
        t.shared = sTotal > 0 ? sDone / Double(sTotal) : nil
        t.total = pTotal + sTotal
        t.done = pDone + sDone
        t.combined = t.total > 0 ? t.done / Double(t.total) : nil
        totals = t
        
        incompleteMonth = interval.contains(today)
        taskSummaries = buildSummaries(in: interval, today: today)
    }
    
    private func buildMonthTiles(in interval: DateInterval) -> [MonthTile] {
        var tiles: [MonthTile] = []
        let today = calendar.startOfDay(for: now())
        var monthStart = interval.start
        while monthStart < interval.end {
            let monthInterval = calendar.dateInterval(of: .month, for: monthStart) ?? DateInterval(start: monthStart, duration: 30 * 86_400)
            var pDone = 0.0, pTotal = 0, sDone = 0.0, sTotal = 0
            for day in days(in: monthInterval) {
                let d = filteredDay(day)
                guard !d.isFuture else { continue }
                pDone += d.personalDone; pTotal += d.personalScheduled
                sDone += d.sharedDone; sTotal += d.sharedScheduled
            }
            let total = pTotal + sTotal
            tiles.append(MonthTile(
                id: key(monthStart),
                monthStart: monthStart,
                personalProgress: pTotal > 0 ? pDone / Double(pTotal) : 0,
                sharedProgress: sTotal > 0 ? sDone / Double(sTotal) : 0,
                combinedProgress: total > 0 ? (pDone + sDone) / Double(total) : 0,
                hasData: total > 0,
                isFuture: monthStart > today
            ))
            guard let next = calendar.date(byAdding: .month, value: 1, to: monthStart) else { break }
            monthStart = next
        }
        return tiles
    }
    
    private func buildSummaries(in interval: DateInterval, today: Date) -> [TaskPeriodSummary] {
        let periodDays = days(in: interval)
        return tasks.compactMap { task in
            guard (task.taskType == .personal && filterMode.includesPersonal && task.createdBy == currentPigeonId)
                || (task.taskType == .shared && filterMode.includesShared) else { return nil }
            
            var scheduled = 0, completed = 0, run = 0, best = 0
            for day in periodDays where day <= today && isScheduled(task, on: day) {
                scheduled += 1
                if credit(task, on: key(day)) >= 1 { completed += 1; run += 1; best = max(best, run) } else { run = 0 }
            }
            // Edge case: task created after this period, so it has no history here
            guard scheduled > 0 else { return nil }
            
            let claims = claimedDeservings.filter { claim in
                claim.taskId == task.id && periodDays.contains { key($0) == claim.dateClaimedString }
            }.count
            
            var summary = TaskPeriodSummary(
                id: "\(task.id)_\(key(interval.start))_\(selectedPeriod.label)",
                taskId: task.id,
                taskName: task.name,
                taskType: task.taskType.rawValue,
                periodType: selectedPeriod.label.lowercased(),
                completionDays: completed,
                targetDays: scheduled,
                checkpointsClaimed: claims,
                streakDays: task.consecutiveDaysCompleted,
                maxStreakInPeriod: best
            )
            summary.isIncomplete = interval.contains(today)
            summary.isFirstPeriod = calendar.startOfDay(for: task.createdAt) >= interval.start
            return summary
        }
    }
    
    // MARK: - Filter & period
    
    func applyFilter() { rebuild() }
    
    func switchPeriod(to period: TimePeriod) {
        selectedPeriod = period
        rebuild()
    }
    
    /// Tap a month tile in the quarterly / yearly view to open that month
    func drillDown(to monthStart: Date) {
        selectedMonth = monthStart
        selectedPeriod = .monthly
        rebuild()
    }
    
    func goToToday() {
        selectedMonth = now()
        rebuild()
    }
    
    // MARK: - Navigation
    
    private func shifted(_ direction: Int) -> Date? {
        switch selectedPeriod {
        case .weekly: return calendar.date(byAdding: .weekOfYear, value: direction, to: selectedMonth)
        case .monthly: return calendar.date(byAdding: .month, value: direction, to: selectedMonth)
        case .quarterly: return calendar.date(byAdding: .month, value: 3 * direction, to: selectedMonth)
        case .yearly: return calendar.date(byAdding: .year, value: direction, to: selectedMonth)
        }
    }
    
    func previousPeriod() {
        guard canGoToPreviousPeriod(), let date = shifted(-1) else { return }
        selectedMonth = date
        rebuild()
    }
    
    func nextPeriod() {
        guard canGoToNextPeriod(), let date = shifted(1) else { return }
        selectedMonth = date
        rebuild()
    }
    
    /// Edge case: never navigate into the future
    func canGoToNextPeriod() -> Bool {
        guard let date = shifted(1) else { return false }
        return range(for: selectedPeriod, anchor: date).start <= calendar.startOfDay(for: now())
    }
    
    /// Edge case: nothing exists before the first task
    func canGoToPreviousPeriod() -> Bool {
        guard let date = shifted(-1), let earliest = earliestTaskDay else { return false }
        return range(for: selectedPeriod, anchor: date).end > earliest
    }
    
    // MARK: - Titles
    
    var periodTitle: String {
        let interval = range(for: selectedPeriod, anchor: selectedMonth)
        let f = DateFormatter()
        f.calendar = calendar
        switch selectedPeriod {
        case .weekly:
            f.dateFormat = "MMM d"
            let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            return "\(f.string(from: interval.start)) – \(f.string(from: end))"
        case .monthly:
            f.dateFormat = "MMMM yyyy"
            return f.string(from: interval.start)
        case .quarterly:
            let month = calendar.component(.month, from: interval.start)
            return "Q\((month - 1) / 3 + 1) \(calendar.component(.year, from: interval.start))"
        case .yearly:
            return String(calendar.component(.year, from: interval.start))
        }
    }
}
