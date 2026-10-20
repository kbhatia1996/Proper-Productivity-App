import Foundation

var passed = 0
var failed = 0
func check(_ cond: @autoclosure () -> Bool, _ name: String, file: StaticString = #file, line: UInt = #line) {
    if cond() { passed += 1 } else { failed += 1; print("  FAIL: \(name) (line \(line))") }
}
func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.0001 }
func section(_ s: String) { print("• \(s)") }

let cal = Calendar.current
func date(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }
func key(_ y: Int, _ m: Int, _ d: Int) -> String { String(format: "%04d-%02d-%02d", y, m, d) }

func task(_ id: String, _ type: Task.TaskType, by: String = "me", created: Date, freq: Task.Frequency = .daily) -> Task {
    Task(id: id, nestId: "n", name: id, description: "", taskType: type, frequency: freq, createdBy: by,
         createdAt: created, updatedAt: created, checkpoints: [])
}
func done(_ taskId: String, _ pigeon: String, _ y: Int, _ m: Int, _ d: Int, _ svc: FirebaseService, complete: Bool = true) {
    let k = key(y, m, d)
    svc.completions[taskId, default: [:]][pigeon, default: []].append(
        TaskCompletion(taskId: taskId, pigeonId: pigeon, date: k, isComplete: complete))
}

@MainActor
func makeVM(now: Date, tasks: [Task], members: [String] = ["me", "partner"], setup: (FirebaseService) -> Void = { _ in }) async -> (CalendarViewModel, FirebaseService) {
    let svc = FirebaseService.shared
    svc.tasks = tasks; svc.completions = [:]; svc.claims = []; svc.failCompletionFetchFor = []
    svc.currentPigeon = Pigeon(id: "me", email: "a@b.co", name: "Me", avatar: "", nestId: "n", createdAt: now, lastActiveAt: now)
    svc.currentNest = Nest(id: "n", name: "n", theme: "t", createdBy: "me", pigeons: members, inviteCode: "X",
                           inviteExpiresAt: now.addingTimeInterval(1e6), createdAt: now, updatedAt: now)
    setup(svc)
    let tvm = TaskViewModel()
    let vm = CalendarViewModel(firebaseService: svc, taskViewModel: tvm, now: { now }, autoLoad: false)
    await vm.loadCalendarData()
    return (vm, svc)
}

@MainActor
func runAll() async {
    let today = date(2026, 10, 20)           // Tuesday
    let created = date(2026, 10, 1)

    section("Month grid & weekday alignment")
    do {
        let (vm, _) = await makeVM(now: today, tasks: [task("read", .personal, created: created)])
        check(vm.calendarDays.count == 31, "Oct 2026 has 31 days")
        check(vm.leadingBlankDays == 4, "Oct 1 2026 is Thursday -> 4 blanks (got \(vm.leadingBlankDays))")
        check(vm.periodTitle == "October 2026", "title")
        let (leap, _) = await makeVM(now: date(2024, 2, 10), tasks: [task("r", .personal, created: date(2024, 1, 1))])
        check(leap.calendarDays.count == 29, "Feb 2024 leap year has 29 days")
        check(leap.leadingBlankDays == 4, "Feb 1 2024 is Thursday")
        check(leap.calendarDays.contains { $0.dayOfMonth == 29 }, "Feb 29 exists")
        let (nonLeap, _) = await makeVM(now: date(2026, 2, 10), tasks: [task("r", .personal, created: date(2026, 1, 1))])
        check(nonLeap.calendarDays.count == 28, "Feb 2026 has 28 days")
    }

    section("Personal circle calculation + default filter")
    do {
        let tasks = [task("a", .personal, created: created), task("b", .personal, created: created), task("c", .personal, created: created),
                     task("w", .shared, created: created)]
        let (vm, _) = await makeVM(now: today, tasks: tasks) { s in
            done("a", "me", 2026, 10, 5, s); done("b", "me", 2026, 10, 5, s)       // 2/3 personal
            done("w", "me", 2026, 10, 5, s); done("w", "partner", 2026, 10, 5, s) // shared 1/1
        }
        check(vm.filterMode == .personal, "default filter is personal")
        let d5 = vm.calendarDays.first { $0.dayOfMonth == 5 }!
        check(near(d5.personalProgress, 2.0 / 3.0), "personal 2/3 (got \(d5.personalProgress))")
        check(d5.sharedScheduled == 0 && d5.sharedProgress == 0, "shared hidden under personal filter")
        check(vm.totals.shared == nil, "no shared total under personal")
        
        vm.filterMode = .both; vm.applyFilter()
        let b5 = vm.calendarDays.first { $0.dayOfMonth == 5 }!
        check(near(b5.personalProgress, 2.0 / 3.0) && near(b5.sharedProgress, 1), "both shows both rings")
        check(near(b5.combinedProgress, 3.0 / 4.0), "combined = (2+1)/(3+1)")
        
        vm.filterMode = .shared; vm.applyFilter()
        let s5 = vm.calendarDays.first { $0.dayOfMonth == 5 }!
        check(s5.personalScheduled == 0 && near(s5.sharedProgress, 1), "shared-only hides personal")
        
        vm.filterMode = .personal; vm.applyFilter()
        let p5 = vm.calendarDays.first { $0.dayOfMonth == 5 }!
        check(near(p5.personalProgress, 2.0 / 3.0), "switching back restores personal (no data loss)")
    }

    section("Shared tasks: both partners required, partial credit")
    do {
        let (vm, _) = await makeVM(now: today, tasks: [task("w", .shared, created: created)]) { s in
            done("w", "me", 2026, 10, 6, s)                                      // only me
            done("w", "me", 2026, 10, 7, s); done("w", "partner", 2026, 10, 7, s) // both
            done("w", "me", 2026, 10, 8, s, complete: false)                     // unchecked
        }
        vm.filterMode = .shared; vm.applyFilter()
        func p(_ d: Int) -> Double { vm.calendarDays.first { $0.dayOfMonth == d }!.sharedProgress }
        check(near(p(6), 0.5), "one partner = 50%")
        check(near(p(7), 1.0), "both partners = 100%")
        check(near(p(8), 0), "is_complete=false counts as nothing")
        check(vm.taskSummaries.first?.completionDays == 1, "summary counts only fully-done days")
    }

    section("Partner's personal tasks never appear in my calendar")
    do {
        let (vm, _) = await makeVM(now: today, tasks: [task("mine", .personal, created: created), task("theirs", .personal, by: "partner", created: created)])
        check(vm.calendarDays.first!.personalScheduled == 1, "only my personal task scheduled")
        check(vm.taskSummaries.count == 1 && vm.taskSummaries[0].taskId == "mine", "summary has only mine")
    }

    section("Task created mid-month / weekly tasks / no-data days")
    do {
        let (vm, _) = await makeVM(now: today, tasks: [task("late", .personal, created: date(2026, 10, 15))])
        check(vm.calendarDays.first { $0.dayOfMonth == 14 }!.hasNoData, "before creation = no data")
        check(!vm.calendarDays.first { $0.dayOfMonth == 15 }!.hasNoData, "creation day scheduled")
        let (wk, _) = await makeVM(now: today, tasks: [task("weekly", .personal, created: date(2026, 10, 1), freq: .weekly)])
        let scheduled = wk.calendarDays.filter { !$0.hasNoData }.map { $0.dayOfMonth }
        check(scheduled == [1, 8, 15, 22, 29], "weekly task only on creation weekday (got \(scheduled))")
        let (past, _) = await makeVM(now: date(2026, 9, 10), tasks: [task("late", .personal, created: date(2026, 10, 15))])
        check(past.calendarDays.allSatisfy { $0.hasNoData }, "month before any task: all no-data")
        check(past.totals.combined == nil && past.totals.total == 0, "no NaN / nil totals")
    }

    section("Future days & totals only count tracked days")
    do {
        let (vm, _) = await makeVM(now: today, tasks: [task("r", .personal, created: created)]) { s in
            for d in 1...20 { done("r", "me", 2026, 10, d, s) }
        }
        let fut = vm.calendarDays.first { $0.dayOfMonth == 25 }!
        check(fut.isFuture && fut.personalProgress == 0, "future day flagged, 0 progress")
        check(vm.totals.total == 20 && near(vm.totals.personal ?? -1, 1.0), "totals exclude future days: \(vm.totals.total)")
        check(vm.totals.perfectDays == 20, "20 perfect days")
        check(vm.incompleteMonth, "current month flagged in progress")
    }

    section("Empty states / failures")
    do {
        let (vm, _) = await makeVM(now: today, tasks: [])
        check(vm.taskSummaries.isEmpty, "no tasks -> no summaries")
        check(vm.totals.combined == nil, "no tasks -> no percentage")
        check(!vm.canGoToPreviousPeriod(), "can't go back with no tasks")
        check(vm.calendarDays.allSatisfy { $0.progressSafe }, "no NaN in progress")
        
        let (gap, _) = await makeVM(now: today, tasks: [task("w", .shared, created: created)]) { $0.failCompletionFetchFor = ["partner"] }
        check(gap.hasDataGaps && gap.errorMessage != nil, "failed partner fetch flags a data gap")
        
        let svc = FirebaseService.shared
        svc.currentNest = nil
        let vm2 = CalendarViewModel(firebaseService: svc, taskViewModel: TaskViewModel(), now: { today }, autoLoad: false)
        await vm2.loadCalendarData()
        check(vm2.errorMessage?.contains("nest") == true, "no nest -> friendly message")
        
        let (solo, _) = await makeVM(now: today, tasks: [task("w", .shared, created: created)], members: []) { s in done("w", "me", 2026, 10, 3, s) }
        solo.filterMode = .shared; solo.applyFilter()
        check(near(solo.calendarDays.first { $0.dayOfMonth == 3 }!.sharedProgress, 1), "empty member list falls back to me (no divide by zero)")
    }

    section("Period navigation & boundaries")
    do {
        let tasks = [task("r", .personal, created: date(2025, 11, 12))]
        let (vm, _) = await makeVM(now: today, tasks: tasks)
        check(!vm.canGoToNextPeriod(), "cannot go to future month")
        vm.switchPeriod(to: .weekly)
        check(vm.periodTitle == "Oct 18 – Oct 24", "week title (got \(vm.periodTitle))")
        check(vm.calendarDays.count == 7, "week has 7 days")
        check(!vm.canGoToNextPeriod(), "cannot go to future week")
        vm.previousPeriod()
        check(vm.periodTitle == "Oct 11 – Oct 17", "previous week")
        vm.nextPeriod()
        
        vm.switchPeriod(to: .quarterly)
        check(vm.periodTitle == "Q4 2026", "Q4 title")
        check(vm.monthTiles.count == 3, "quarter has 3 month tiles")
        check(vm.monthTiles.last!.isFuture, "Dec tile is future")
        vm.previousPeriod(); vm.previousPeriod()
        check(vm.periodTitle == "Q2 2026", "two quarters back = Q2 (got \(vm.periodTitle))")
        
        vm.switchPeriod(to: .yearly)
        check(vm.monthTiles.count == 12, "year has 12 tiles")
        check(vm.monthTiles[0].hasData && vm.monthTiles[11].isFuture, "Jan has data, Dec is future")
        vm.previousPeriod()
        check(vm.periodTitle == "2025", "previous year")
        check(vm.monthTiles[0].hasData == false && vm.monthTiles[10].hasData, "2025: Jan empty, Nov has data")
        check(!vm.canGoToPreviousPeriod(), "can't go before first task year")
        
        vm.drillDown(to: date(2025, 11, 1))
        check(vm.selectedPeriod == .monthly && vm.periodTitle == "November 2025", "drill down from tile")
        vm.goToToday()
        check(vm.periodTitle == "October 2026", "today button")
        
        // Year rollover for a quarter / month
        let (dec, _) = await makeVM(now: date(2026, 12, 15), tasks: tasks)
        dec.switchPeriod(to: .monthly); dec.nextPeriod()
        check(dec.periodTitle == "December 2026", "can't leave current month")
        let (jan, _) = await makeVM(now: date(2026, 1, 5), tasks: tasks)
        jan.previousPeriod()
        check(jan.periodTitle == "December 2025", "Jan -> Dec crosses year")
    }

    section("Deserving claims shown on the day")
    do {
        let k = key(2026, 10, 10)
        let deserving = Deserving(id: "d", taskId: "r", checkpointOrder: 1, title: "Gaming", description: "", createdBy: "me", createdAt: created)
        let (vm, _) = await makeVM(now: today, tasks: [task("r", .personal, created: created), task("w", .shared, created: created)]) { s in
            s.claims = [ClaimedDeserving(id: "c", taskId: "r", deserving: deserving, pigeonId: "me", dateClaimedString: k, claimedAt: created, taskType: .personal)]
        }
        check(vm.calendarDays.first { $0.dayOfMonth == 10 }!.personalCheckpointsClaimed == 1, "claim marks Oct 10")
        check(vm.taskSummaries.first { $0.taskId == "r" }?.checkpointsClaimed == 1, "summary counts claim in period")
        vm.filterMode = .shared; vm.applyFilter()
        check(vm.calendarDays.first { $0.dayOfMonth == 10 }!.personalCheckpointsClaimed == 0, "hidden under shared filter")
    }

    section("Streaks in summary")
    do {
        let (vm, _) = await makeVM(now: today, tasks: [task("r", .personal, created: created)]) { s in
            for d in [1, 2, 3, 5, 6, 7, 8, 9] { done("r", "me", 2026, 10, d, s) }
        }
        check(vm.taskSummaries[0].maxStreakInPeriod == 5, "best streak 5 (got \(vm.taskSummaries[0].maxStreakInPeriod))")
        check(vm.taskSummaries[0].completionDays == 8, "8 completed days")
    }

    section("Time zones & DST (current TZ: \(TimeZone.current.identifier))")
    do {
        for (y, m, expected) in [(2026, 3, 31), (2026, 11, 30), (2026, 10, 31), (2026, 4, 30)] {
            let (vm, _) = await makeVM(now: date(y, m, 20), tasks: [task("r", .personal, created: date(2026, 1, 1))])
            let keys = Set(vm.calendarDays.map { $0.id })
            check(vm.calendarDays.count == expected && keys.count == expected, "\(y)-\(m) has \(expected) unique days (got \(vm.calendarDays.count))")
        }
    }

    section("Codable / legacy data")
    do {
        let legacy = #"{"id":"u1","email":"a@b.co","name":"A","avatar":"pigeon_1","rank":"C","xp":420,"created_at":0,"last_active_at":0}"#.data(using: .utf8)!
        let dec = JSONDecoder()
        let p = try? dec.decode(Pigeon.self, from: legacy)
        check(p != nil && p?.totalTasksCompleted == 0, "legacy pigeon (rank/xp, no total) decodes")
        check(p?.avatarEmoji == "🐦", "legacy pigeon avatar maps to emoji")
        check(Pigeon(id: "x", email: "", name: "", avatar: "🦉", createdAt: Date(), lastActiveAt: Date()).avatarEmoji == "🦉", "new emoji avatar is preserved")
        let noId = #"{"task_id":"t","pigeon_id":"p","date":"2026-10-01","is_complete":true,"created_at":0,"updated_at":0}"#.data(using: .utf8)!
        let c = try? dec.decode(TaskCompletion.self, from: noId)
        check(c?.id == "t_p_2026-10-01", "completion without id decodes with derived id")
        let enc = try? JSONEncoder().encode(Pigeon(id: "x", email: "e@e.co", name: "n", avatar: "a", totalTasksCompleted: 7, createdAt: Date(), lastActiveAt: Date()))
        let rt = enc.flatMap { try? dec.decode(Pigeon.self, from: $0) }
        check(rt?.totalTasksCompleted == 7, "pigeon round-trips")
        check(Pigeon(id: "x", email: "", name: "", avatar: "", totalTasksCompleted: 9, createdAt: Date(), lastActiveAt: Date()).consistencyLevel == "Growing", "level 9 Growing")
        check(Pigeon(id: "x", email: "", name: "", avatar: "", totalTasksCompleted: 10, createdAt: Date(), lastActiveAt: Date()).consistencyLevel == "Impressive", "level 10 Impressive")
        check(Pigeon(id: "x", email: "", name: "", avatar: "", totalTasksCompleted: 100, createdAt: Date(), lastActiveAt: Date()).consistencyLevel == "Unstoppable", "level 100 Unstoppable")
        let zero = Checkpoint(id: "c", taskId: "t", order: 1, dayThreshold: 0, deserving: Deserving(id: "d", taskId: "t", checkpointOrder: 1, title: "x", description: "", createdBy: "", createdAt: Date()))
        var t = task("t", .personal, created: Date()); _ = t
        t = Task(id: "t", nestId: "n", name: "", description: "", taskType: .personal, frequency: .daily, createdBy: "", createdAt: Date(), updatedAt: Date(), checkpoints: [zero])
        check(!t.getCurrentCheckpointProgress().percentage.isNaN, "zero threshold doesn't divide by zero")
        let expired = Nest(id: "n", name: "", theme: "", createdBy: "", pigeons: [], inviteCode: "A", inviteExpiresAt: Date().addingTimeInterval(-10), createdAt: Date(), updatedAt: Date())
        check(!expired.isInviteValid, "expired invite invalid")
    }

    section("Auth view model")
    do {
        let svc = FirebaseService.shared
        let vm = AuthViewModel()
        svc.signInCalls = 0; svc.signUpCalls = 0; svc.authShouldSucceed = true
        
        vm.email = ""; vm.password = ""
        await vm.signIn()
        check(vm.errorMessage == "Email and password are required" && svc.signInCalls == 0, "empty sign-in blocked locally")
        vm.email = "not-an-email"; vm.password = "secret1"
        await vm.signIn()
        check(vm.errorMessage == "Enter a valid email address" && svc.signInCalls == 0, "bad email blocked")
        vm.email = "a @b.co"; await vm.signIn()
        check(svc.signInCalls == 0, "email with space blocked")
        
        svc.authShouldSucceed = false
        vm.email = "  me@x.co  "; vm.password = "wrongpw"
        await vm.signIn()
        check(vm.errorMessage == svc.authError && svc.signInCalls == 1, "failed sign-in shows service error")
        check(!vm.isLoading, "loading cleared after failure")
        
        svc.authShouldSucceed = true
        vm.password = "rightpw"
        await vm.signIn()
        check(vm.errorMessage.isEmpty, "no stale error after later success (got '\(vm.errorMessage)')")
        check(vm.password.isEmpty, "password cleared after success")
        
        vm.name = ""; vm.email = "me@x.co"; vm.password = "abcdef"
        await vm.signUp()
        check(vm.errorMessage == "All fields are required" && svc.signUpCalls == 0, "sign-up needs name")
        vm.name = "Me"; vm.password = "123"
        await vm.signUp()
        check(vm.errorMessage == "Password must be at least 6 characters" && svc.signUpCalls == 0, "short password blocked")
        vm.password = "123456"
        await vm.signUp()
        check(vm.errorMessage.isEmpty && svc.signUpCalls == 1, "valid sign-up goes through")
        
        svc.authShouldSucceed = false; svc.authError = "The email address is already in use by another account."
        vm.password = "123456"; vm.email = "me@x.co"
        await vm.signUp()
        check(vm.errorMessage.contains("already in use"), "duplicate account error surfaced")
    }

    section("Nest view model")
    do {
        let svc = FirebaseService.shared
        let vm = NestViewModel()
        svc.nestShouldSucceed = true
        vm.nestName = "   "
        let result1 = await vm.createNest()
        check(result1 == false && vm.errorMessage == "Nest name is required", "blank nest name rejected")
        vm.nestName = "Home"
        let result2 = await vm.createNest()
        check(result2 == true && vm.nestName.isEmpty, "create succeeds & clears form")
        svc.nestShouldSucceed = false
        vm.nestName = "Home"
        let result3 = await vm.createNest()
        check(result3 == false && vm.errorMessage == "Permission denied", "create failure keeps sheet open + message")
        vm.inviteCode = " "
        let result4 = await vm.joinNest()
        check(result4 == false && vm.errorMessage == "Invite code is required", "blank code rejected")
        vm.inviteCode = "zzz999"
        let result5 = await vm.joinNest()
        check(result5 == false && vm.errorMessage == "Invalid invite code", "bad code message")
        svc.nestShouldSucceed = true
        let result6 = await vm.joinNest()
        check(result6 == true, "join succeeds")
    }

    print("\nPassed: \(passed)   Failed: \(failed)")
    exit(failed == 0 ? 0 : 1)
}

extension CalendarDayProgress {
    var progressSafe: Bool { !personalProgress.isNaN && !sharedProgress.isNaN && !combinedProgress.isNaN }
}

await runAll()
