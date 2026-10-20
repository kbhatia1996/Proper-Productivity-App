import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @ObservedObject var taskViewModel: TaskViewModel
    @State private var showNewTaskSheet = false
    @State private var showSettings = false
    @State private var notificationError: String?
    @AppStorage("rewardRemindersEnabled") private var rewardRemindersEnabled = false
    
    var body: some View {
        ZStack {
            SoloLevellingTheme.deepBlack.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with Nest & Pigeon Info
                VStack(spacing: 12) {
                    if let pigeon = firebaseService.currentPigeon {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pigeon.name)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(SoloLevellingTheme.brightGold)
                                HStack(spacing: 8) {
                                    Text(pigeon.consistencyLevel)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(SoloLevellingTheme.progressAccent)
                                    Text("\(pigeon.totalTasksCompleted) completed")
                                        .font(.system(size: 12))
                                        .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
                                }
                            }
                            Spacer()
                            Text(pigeon.avatarEmoji)
                                .font(.system(size: 38))
                                .accessibilityLabel("Profile picture")
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 19))
                                    .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.8))
                                    .padding(8)
                                    .background(SoloLevellingTheme.silverWhite.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("Settings")
                        }
                        .padding()
                        .themeCard()
                    }
                    
                    if let nest = firebaseService.currentNest {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(nest.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(SoloLevellingTheme.silverWhite)
                                Text("Invite: \(nest.inviteCode)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.6))
                            }
                            Spacer()
                            Image(systemName: "house.fill")
                                .font(.system(size: 20))
                                .foregroundColor(SoloLevellingTheme.progressAccent)
                        }
                        .padding()
                        .themeCard()
                    }
                }
                .padding()
                
                // Tasks List
                if taskViewModel.tasks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(SoloLevellingTheme.brightGold.opacity(0.5))
                        Text("No Tasks Yet")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(SoloLevellingTheme.silverWhite)
                        Text("Create your first task to begin your discipline journey")
                            .font(.system(size: 12))
                            .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxHeight: .infinity)
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(taskViewModel.tasks) { task in
                                TaskCardView(task: task, allTasks: taskViewModel.tasks)
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
                
                // New Task Button
                Button(action: { showNewTaskSheet = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New Task")
                    }
                    .frame(maxWidth: .infinity)
                    .modifier(ThemeButton(style: .primary))
                }
                .padding()
            }
        }
        .onAppear {
            if let nestId = firebaseService.currentNest?.id {
                _Concurrency.Task { @MainActor in
                    await taskViewModel.fetchTasks(nestId: nestId)
                    await refreshRewardReminder()
                }
            }
        }
        .sheet(isPresented: $showNewTaskSheet) {
            NewTaskSheet(taskViewModel: taskViewModel, nestId: firebaseService.currentNest?.id ?? "")
        }
        .sheet(isPresented: $showSettings) {
            AppearanceSettingsView(taskViewModel: taskViewModel)
        }
        .onChange(of: taskViewModel.tasks.count) { _ in
            guard rewardRemindersEnabled else { return }
            _Concurrency.Task { @MainActor in await refreshRewardReminder() }
        }
        .alert("Reward reminder couldn't be updated", isPresented: Binding(
            get: { notificationError != nil },
            set: { if !$0 { notificationError = nil } }
        )) {
            Button("OK", role: .cancel) { notificationError = nil }
        } message: {
            Text(notificationError ?? "")
        }
    }

    @MainActor
    private func refreshRewardReminder() async {
        guard rewardRemindersEnabled, let pigeonId = firebaseService.currentPigeon?.id else { return }
        do {
            try await RewardNotificationService.shared.refreshUpcomingReminder(
                tasks: taskViewModel.tasks,
                pigeonId: pigeonId
            )
        } catch {
            notificationError = error.localizedDescription
        }
    }
}

struct TaskCardView: View {
    let task: Task
    let allTasks: [Task]
    @EnvironmentObject var firebaseService: FirebaseService
    @State private var isComplete = false
    @State private var completedDays = 0
    @State private var isSaving = false
    @State private var notificationError: String?
    @AppStorage("rewardRemindersEnabled") private var rewardRemindersEnabled = false
    
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private var todayKey: String { Self.dayFormatter.string(from: Date()) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SoloLevellingTheme.brightGold)
                    Text(task.description)
                        .font(.system(size: 12))
                        .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
                }
                Spacer()
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isComplete ? SoloLevellingTheme.successGreen : SoloLevellingTheme.silverWhite.opacity(0.4))
                    .onTapGesture { toggleToday() }
            }
            
            // Checkpoint Progress
            if let next = task.checkpoints.sorted(by: { $0.order < $1.order }).first(where: { completedDays < $0.dayThreshold })
                ?? task.checkpoints.last {
                HStack(spacing: 8) {
                    Text("Next: \(next.deserving.title)")
                        .font(.system(size: 11))
                        .foregroundColor(SoloLevellingTheme.progressGold)
                    Spacer()
                    Text("\(min(completedDays, next.dayThreshold))/\(next.dayThreshold) days")
                        .font(.system(size: 11))
                        .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.6))
                }
            }
        }
        .padding()
        .themeCard()
        .onAppear { _Concurrency.Task { @MainActor in await loadState() } }
        .alert("Reward reminder couldn't be updated", isPresented: Binding(
            get: { notificationError != nil },
            set: { if !$0 { notificationError = nil } }
        )) {
            Button("OK", role: .cancel) { notificationError = nil }
        } message: {
            Text(notificationError ?? "")
        }
    }
    
    private func loadState() async {
        guard let pigeonId = firebaseService.currentPigeon?.id,
              let completions = await firebaseService.fetchCompletions(taskId: task.id, pigeonId: pigeonId) else { return }
        let done = completions.filter { $0.isComplete }
        completedDays = done.count
        isComplete = done.contains { $0.date == todayKey }
    }
    
    /// Saves the check-in so the calendar and streaks see it; ignores taps while a save is in flight
    private func toggleToday() {
        guard !isSaving, let pigeonId = firebaseService.currentPigeon?.id else { return }
        isSaving = true
        let newValue = !isComplete
        isComplete = newValue
        completedDays = max(0, completedDays + (newValue ? 1 : -1))
        _Concurrency.Task { @MainActor in
            await firebaseService.markTaskComplete(taskId: task.id, pigeonId: pigeonId, date: todayKey, isComplete: newValue)
            await loadState()   // reconcile with what was actually stored
            if rewardRemindersEnabled {
                do {
                    try await RewardNotificationService.shared.refreshUpcomingReminder(
                        tasks: allTasks,
                        pigeonId: pigeonId
                    )
                } catch {
                    notificationError = error.localizedDescription
                }
            }
            isSaving = false
        }
    }
}

struct NewTaskSheet: View {
    @ObservedObject var taskViewModel: TaskViewModel
    let nestId: String
    @Environment(\.dismiss) var dismiss
    @State private var deservingTitles: [String] = ["", "", ""]
    @State private var deservingDescriptions: [String] = ["", "", ""]
    
    var body: some View {
        ZStack {
            SoloLevellingTheme.darkPurple.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    Text("Create New Task")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(SoloLevellingTheme.brightGold)
                    
                    TextField("Task Name", text: $taskViewModel.taskName)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Description", text: $taskViewModel.taskDescription)
                        .textFieldStyle(.roundedBorder)
                    
                    Picker("Type", selection: $taskViewModel.taskType) {
                        Text("Personal").tag(Task.TaskType.personal)
                        Text("Shared").tag(Task.TaskType.shared)
                    }
                    .pickerStyle(.segmented)
                    .tint(SoloLevellingTheme.brightGold)
                    
                    Text("Checkpoints & Deservings")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SoloLevellingTheme.brightGold)
                    
                    ForEach(0..<3, id: \.self) { index in
                        VStack(spacing: 8) {
                            TextField("Days", value: Binding(
                                get: { taskViewModel.checkpointThresholds[safe: index] ?? 0 },
                                set: {
                                    if index < taskViewModel.checkpointThresholds.count {
                                        taskViewModel.checkpointThresholds[index] = $0
                                    }
                                }
                            ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                            
                            TextField("Deserving Title", text: Binding(
                                get: { deservingTitles[safe: index] ?? "" },
                                set: {
                                    if index < deservingTitles.count {
                                        deservingTitles[index] = $0
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                    
                    Button(action: {
                        _Concurrency.Task {
                            let deserving = deservingTitles.enumerated().map { index, title in
                                (title: title, description: index < deservingDescriptions.count ? deservingDescriptions[index] : "")
                            }
                            await taskViewModel.createTask(nestId: nestId, deserving: deserving)
                            dismiss()
                        }
                    }) {
                        if taskViewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Create Task")
                        }
                    }
                    .modifier(ThemeButton(style: .primary))
                    .disabled(taskViewModel.isLoading)
                    
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .modifier(ThemeButton(style: .secondary))
                    }
                }
                .padding()
            }
        }
    }
}

#Preview {
    DashboardView(taskViewModel: TaskViewModel())
        .environmentObject(FirebaseService.shared)
}
