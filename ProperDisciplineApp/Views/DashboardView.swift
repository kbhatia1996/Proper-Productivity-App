import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @StateObject private var taskViewModel = TaskViewModel()
    @State private var showNewTaskSheet = false
    
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
                                    Text("Rank: \(pigeon.rank)")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.rankColor(for: pigeon.rank))
                                    Text("XP: \(pigeon.xp)")
                                        .font(.system(size: 12))
                                        .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
                                }
                            }
                            Spacer()
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(SoloLevellingTheme.brightGold)
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
                                    .font(.system(size: 11, weight: .monospaced))
                                    .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.6))
                            }
                            Spacer()
                            Image(systemName: "house.fill")
                                .font(.system(size: 20))
                                .foregroundColor(SoloLevellingTheme.rankC)
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
                                TaskCardView(task: task)
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
                Task {
                    await taskViewModel.fetchTasks(nestId: nestId)
                }
            }
        }
        .sheet(isPresented: $showNewTaskSheet) {
            NewTaskSheet(taskViewModel: taskViewModel, nestId: firebaseService.currentNest?.id ?? "")
        }
    }
}

struct TaskCardView: View {
    let task: Task
    @State private var isComplete = false
    
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
                    .foregroundColor(isComplete ? SoloLevellingTheme.successGreen : SoloLevellingTheme.rankE)
                    .onTapGesture {
                        isComplete.toggle()
                    }
            }
            
            // Checkpoint Progress
            if !task.checkpoints.isEmpty {
                HStack(spacing: 8) {
                    Text("Next: \(task.checkpoints[0].deserving.title)")
                        .font(.system(size: 11))
                        .foregroundColor(SoloLevellingTheme.rankB)
                    Spacer()
                    Text("0/\(task.checkpoints[0].dayThreshold) days")
                        .font(.system(size: 11))
                        .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.6))
                }
            }
        }
        .padding()
        .themeCard()
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
                            TextField("Days", value: $taskViewModel.checkpointThresholds[safe: index] ?? 0, format: .number)
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
                        Task {
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
    DashboardView()
        .environmentObject(FirebaseService.shared)
}
