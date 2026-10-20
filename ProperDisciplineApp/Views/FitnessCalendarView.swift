import SwiftUI

struct FitnessCalendarView: View {
    @StateObject private var viewModel: CalendarViewModel
    @EnvironmentObject var firebaseService: FirebaseService
    @State private var selectedDay: CalendarDayProgress?
    @State private var showDeservingDetail = false
    
    let taskViewModel: TaskViewModel
    
    init(taskViewModel: TaskViewModel, firebaseService: FirebaseService) {
        self.taskViewModel = taskViewModel
        _viewModel = StateObject(wrappedValue: CalendarViewModel(firebaseService: firebaseService, taskViewModel: taskViewModel))
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    SoloLevellingTheme.deepBlack,
                    SoloLevellingTheme.darkPurple
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header
                VStack(spacing: 12) {
                    HStack {
                        Text("Progress Circle")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(SoloLevellingTheme.brightGold)
                        Spacer()
                        Image(systemName: "calendar")
                            .font(.system(size: 18))
                            .foregroundColor(SoloLevellingTheme.brightGold)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Filter Controls
                    filterControlsView
                    
                    // Time Period Selector
                    timePeriodSelector
                }
                .padding(.bottom, 16)
                
                // MARK: - Calendar Grid
                if viewModel.isLoading {
                    ProgressView()
                        .tint(SoloLevellingTheme.brightGold)
                        .frame(maxHeight: .infinity)
                } else {
                    calendarGridView
                }
                
                // MARK: - Error Message
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                        Text(error)
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                    .padding(12)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(8)
                    .padding(16)
                }
                
                // MARK: - Data Quality Warnings (Edge Cases)
                if viewModel.hasDataGaps {
                    dataGapsWarning
                }
                
                if viewModel.incompleteMonth {
                    incompleteMonthNotice
                }
                
                // MARK: - Task Summaries
                taskSummariesView
                
                Spacer()
            }
        }
        .onAppear {
            // Pick up check-ins made on the Home tab
            _Concurrency.Task { await viewModel.loadCalendarData() }
        }
        .sheet(item: $selectedDay) { day in
            dayDetailView(for: day)
        }
    }
    
    // MARK: - Filter Controls
    
    var filterControlsView: some View {
        HStack(spacing: 12) {
            ForEach([CalendarViewModel.FilterMode.personal, .shared, .both], id: \.self) { mode in
                Button(action: {
                    viewModel.filterMode = mode
                    viewModel.applyFilter()
                }) {
                    Text(mode.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(viewModel.filterMode == mode ?
                            Color.black :
                            SoloLevellingTheme.silverWhite)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(viewModel.filterMode == mode ?
                            SoloLevellingTheme.brightGold :
                            SoloLevellingTheme.silverWhite.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Time Period Selector
    
    var timePeriodSelector: some View {
        HStack(spacing: 8) {
            ForEach([
                CalendarViewModel.TimePeriod.weekly,
                .monthly,
                .quarterly,
                .yearly
            ], id: \.self) { period in
                Button(action: {
                    viewModel.switchPeriod(to: period)
                }) {
                    Text(period.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(viewModel.selectedPeriod == period ?
                            SoloLevellingTheme.brightGold :
                            SoloLevellingTheme.silverWhite.opacity(0.7))
                        .frame(height: 28)
                        .frame(maxWidth: .infinity)
                        .background(viewModel.selectedPeriod == period ?
                            SoloLevellingTheme.silverWhite.opacity(0.1) :
                            Color.clear)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(viewModel.selectedPeriod == period ?
                                    SoloLevellingTheme.brightGold :
                                    Color.clear, lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Calendar Grid
    
    var calendarGridView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Period navigation
                HStack {
                    Button(action: { viewModel.previousPeriod() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(viewModel.canGoToPreviousPeriod() ?
                                SoloLevellingTheme.brightGold :
                                SoloLevellingTheme.silverWhite.opacity(0.5))
                            .frame(width: 32, height: 32)
                    }
                    .disabled(!viewModel.canGoToPreviousPeriod())
                    
                    Text(viewModel.periodTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(SoloLevellingTheme.silverWhite)
                        .frame(maxWidth: .infinity)
                    
                    Button(action: { viewModel.nextPeriod() }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(viewModel.canGoToNextPeriod() ?
                                SoloLevellingTheme.brightGold :
                                SoloLevellingTheme.silverWhite.opacity(0.5))
                            .frame(width: 32, height: 32)
                    }
                    .disabled(!viewModel.canGoToNextPeriod())
                }
                .padding(.horizontal, 20)
                
                if !viewModel.incompleteMonth {
                    Button("Today") { viewModel.goToToday() }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(SoloLevellingTheme.brightGold)
                }
                
                periodSummaryHeader
                
                switch viewModel.selectedPeriod {
                case .weekly, .monthly:
                    dayGrid
                case .quarterly, .yearly:
                    monthTileGrid
                }
                
                Spacer(minLength: 20)
            }
        }
    }
    
    /// Aggregate ring + counts for the visible period; follows the active filter
    var periodSummaryHeader: some View {
        let totals = viewModel.totals
        return HStack(spacing: 16) {
            ZStack {
                if viewModel.filterMode == .both {
                    ringTrack(SoloLevellingTheme.calendarSharedAccent, progress: totals.shared ?? 0, lineWidth: 8)
                    ringTrack(SoloLevellingTheme.calendarPersonalAccent, progress: totals.personal ?? 0, lineWidth: 8)
                        .padding(11)
                } else if viewModel.filterMode == .shared {
                    ringTrack(SoloLevellingTheme.calendarSharedAccent, progress: totals.shared ?? 0, lineWidth: 8)
                } else {
                    ringTrack(SoloLevellingTheme.calendarPersonalAccent, progress: totals.personal ?? 0, lineWidth: 8)
                }
                Text(totals.combined.map { "\(Int($0 * 100))%" } ?? "–")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(SoloLevellingTheme.silverWhite)
            }
            .frame(width: 86, height: 86)
            
            VStack(alignment: .leading, spacing: 4) {
                if totals.total > 0 {
                    Text("\(Int(totals.done.rounded())) of \(totals.total) check-ins")
                        .font(.system(size: 13, weight: .semibold))
                    Text("\(totals.perfectDays) perfect day\(totals.perfectDays == 1 ? "" : "s")")
                        .font(.system(size: 12))
                } else {
                    // Edge case: nothing scheduled for this filter / period
                    Text("No goals tracked in this period")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundColor(SoloLevellingTheme.silverWhite)
            Spacer()
        }
        .padding(14)
        .background(SoloLevellingTheme.darkPurple)
        .cornerRadius(14)
        .padding(.horizontal, 20)
    }
    
    func ringTrack(_ color: Color, progress: Double, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
    
    var dayGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                }
            }
            LazyVGrid(columns: columns, spacing: 12) {
                // Leading blanks put day 1 under its real weekday
                ForEach(0..<viewModel.leadingBlankDays, id: \.self) { _ in
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
                ForEach(viewModel.calendarDays) { day in
                    progressCircleCell(for: day)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    /// Quarterly / yearly: one aggregate ring per month, tap to open the month
    var monthTileGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(viewModel.monthTiles) { tile in
                Button(action: { viewModel.drillDown(to: tile.monthStart) }) {
                    VStack(spacing: 6) {
                        Text(monthName(tile.monthStart))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(SoloLevellingTheme.silverWhite)
                        ZStack {
                            if tile.isFuture || !tile.hasData {
                                Circle()
                                    .stroke(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                            } else if viewModel.filterMode == .both {
                                ringTrack(SoloLevellingTheme.calendarSharedAccent, progress: tile.sharedProgress, lineWidth: 6)
                                ringTrack(SoloLevellingTheme.calendarPersonalAccent, progress: tile.personalProgress, lineWidth: 6)
                                    .padding(8)
                            } else if viewModel.filterMode == .shared {
                                ringTrack(SoloLevellingTheme.calendarSharedAccent, progress: tile.sharedProgress, lineWidth: 6)
                            } else {
                                ringTrack(SoloLevellingTheme.calendarPersonalAccent, progress: tile.personalProgress, lineWidth: 6)
                            }
                            if tile.hasData && !tile.isFuture {
                                Text("\(Int(tile.combinedProgress * 100))%")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(SoloLevellingTheme.silverWhite)
                            }
                        }
                        .frame(width: 64, height: 64)
                        Text(tile.isFuture ? "upcoming" : (tile.hasData ? " " : "no data"))
                            .font(.system(size: 10))
                            .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(SoloLevellingTheme.darkPurple)
                    .cornerRadius(12)
                }
                .disabled(tile.isFuture || !tile.hasData)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Progress Circle Cell (Apple Fitness style)
    
    func progressCircleCell(for day: CalendarDayProgress) -> some View {
        let personalColor = SoloLevellingTheme.calendarPersonalAccent
        let sharedColor = SoloLevellingTheme.calendarSharedAccent
        return Button(action: { selectedDay = day }) {
            ZStack {
                if day.hasNoData {
                    // Rest day, before the first task, or filtered out
                    Circle()
                        .stroke(Color.gray.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                } else if viewModel.filterMode == .both {
                    ringTrack(sharedColor, progress: day.sharedProgress, lineWidth: 4)
                    ringTrack(personalColor, progress: day.personalProgress, lineWidth: 4)
                        .padding(5)
                } else if viewModel.filterMode == .shared {
                    ringTrack(sharedColor, progress: day.sharedProgress, lineWidth: 5)
                } else {
                    ringTrack(personalColor, progress: day.personalProgress, lineWidth: 5)
                }
                
                VStack(spacing: 0) {
                    Text("\(day.dayOfMonth)")
                        .font(.system(size: 12, weight: Calendar.current.isDateInToday(day.date) ? .bold : .medium))
                        .foregroundColor(day.hasNoData || day.isFuture ?
                            SoloLevellingTheme.silverWhite.opacity(0.5) :
                            SoloLevellingTheme.silverWhite)
                    
                    // Star when a deserving was claimed that day
                    if day.personalCheckpointsClaimed > 0 || day.sharedCheckpointsClaimed > 0 {
                        Image(systemName: "star.fill")
                            .font(.system(size: 7))
                            .foregroundColor(SoloLevellingTheme.brightGold)
                    }
                }
                
                if Calendar.current.isDateInToday(day.date) {
                    Circle()
                        .stroke(SoloLevellingTheme.brightGold, lineWidth: 1.5)
                        .padding(-2)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(dateFormatter.string(from: day.date)), \(day.hasNoData ? "no goals" : "\(Int(day.combinedProgress * 100)) percent complete")")
    }
    
    // MARK: - Day Detail View
    
    func dayDetailView(for day: CalendarDayProgress) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text(dateFormatter.string(from: day.date))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(SoloLevellingTheme.brightGold)
                Spacer()
                Button(action: { selectedDay = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
                }
            }
            .padding()
            
            Divider()
                .background(SoloLevellingTheme.silverWhite.opacity(0.3))
            
            if day.hasNoData {
                Text(day.isFuture ? "Upcoming day" : "No goals were scheduled on this day.")
                    .font(.system(size: 13))
                    .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
                    .padding()
            }
            
            // Personal Progress
            if viewModel.filterMode.includesPersonal && day.personalScheduled > 0 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Personal Goals")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
                
                HStack {
                    ZStack {
                        Circle()
                            .fill(SoloLevellingTheme.darkPurple)
                        
                        Circle()
                            .trim(from: 0, to: day.personalProgress)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        SoloLevellingTheme.calendarPersonalAccent,
                                        SoloLevellingTheme.calendarPersonalAccent
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(day.personalProgress * 100))%")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SoloLevellingTheme.silverWhite)
                    }
                    .frame(width: 80, height: 80)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Completion: \(Int(day.personalProgress * 100))%")
                            .font(.system(size: 13))
                            .foregroundColor(SoloLevellingTheme.silverWhite)
                        
                        if day.personalCheckpointsClaimed > 0 {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(SoloLevellingTheme.brightGold)
                                Text("\(day.personalCheckpointsClaimed) deserving(s) claimed")
                                    .font(.system(size: 12))
                                    .foregroundColor(SoloLevellingTheme.brightGold)
                            }
                        } else {
                            Text("No deservings claimed")
                                .font(.system(size: 12))
                                .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(12)
            .background(SoloLevellingTheme.darkPurple)
            .cornerRadius(8)
            
            }
            
            // Shared Progress
            if viewModel.filterMode.includesShared && day.sharedScheduled > 0 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Shared Goals")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
                
                HStack {
                    ZStack {
                        Circle()
                            .fill(SoloLevellingTheme.darkPurple)
                        
                        Circle()
                            .trim(from: 0, to: day.sharedProgress)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        SoloLevellingTheme.calendarSharedAccent,
                                        SoloLevellingTheme.brightGold
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(day.sharedProgress * 100))%")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SoloLevellingTheme.silverWhite)
                    }
                    .frame(width: 80, height: 80)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Completion: \(Int(day.sharedProgress * 100))%")
                            .font(.system(size: 13))
                            .foregroundColor(SoloLevellingTheme.silverWhite)
                        
                        if day.sharedCheckpointsClaimed > 0 {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(SoloLevellingTheme.brightGold)
                                Text("\(day.sharedCheckpointsClaimed) deserving(s) claimed")
                                    .font(.system(size: 12))
                                    .foregroundColor(SoloLevellingTheme.brightGold)
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(12)
            .background(SoloLevellingTheme.darkPurple)
            .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    SoloLevellingTheme.deepBlack,
                    SoloLevellingTheme.darkPurple
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    // MARK: - Data Quality Warnings
    
    var dataGapsWarning: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(SoloLevellingTheme.warningOrange)
            Text("Some check-ins couldn't be loaded. Check your connection and reopen this tab.")
                .font(.caption)
                .foregroundColor(SoloLevellingTheme.warningOrange)
            Spacer()
        }
        .padding(12)
        .background(SoloLevellingTheme.warningOrange.opacity(0.15))
        .cornerRadius(8)
        .padding(16)
    }
    
    var incompleteMonthNotice: some View {
        HStack {
            Image(systemName: "calendar.badge.clock")
                .foregroundColor(SoloLevellingTheme.calendarPersonalAccent)
            Text("This period is still in progress. Only days up to today count.")
                .font(.caption)
                .foregroundColor(SoloLevellingTheme.calendarPersonalAccent)
            Spacer()
        }
        .padding(12)
        .background(SoloLevellingTheme.calendarPersonalAccent.opacity(0.15))
        .cornerRadius(8)
        .padding(16)
    }
    
    // MARK: - Task Summaries
    
    var taskSummariesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Period Summary (\(viewModel.selectedPeriod.label))")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SoloLevellingTheme.brightGold)
                .padding(.horizontal, 20)
            
            if viewModel.taskSummaries.isEmpty {
                Text("No tasks yet")
                    .font(.caption)
                    .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
                    .padding(20)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.taskSummaries) { summary in
                        taskSummaryRow(for: summary)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 16)
    }
    
    func taskSummaryRow(for summary: TaskPeriodSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.taskName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(SoloLevellingTheme.silverWhite)
                    
                    HStack(spacing: 8) {
                        Text(summary.taskType == "personal" ? "Personal" : "Shared")
                            .font(.system(size: 11))
                            .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
                        
                        if summary.isIncomplete {
                            Text("•")
                                .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
                            Text("In Progress")
                                .font(.system(size: 11))
                                .foregroundColor(SoloLevellingTheme.calendarPersonalAccent)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(summary.completionDays)/\(summary.targetDays) days")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(SoloLevellingTheme.brightGold)
                    
                    Text("\(Int(summary.progressPercentage))%")
                        .font(.system(size: 11))
                        .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
                }
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(SoloLevellingTheme.darkPurple)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    SoloLevellingTheme.calendarPersonalAccent,
                                    SoloLevellingTheme.brightGold
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * summary.progressPercentage / 100)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(SoloLevellingTheme.darkPurple)
        .cornerRadius(8)
    }
    
    // MARK: - Helpers
    
    private func monthName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter
    }()
}
