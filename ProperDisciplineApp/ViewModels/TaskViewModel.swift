import SwiftUI

@MainActor
class TaskViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    @Published var taskName = ""
    @Published var taskDescription = ""
    @Published var taskType: Task.TaskType = .personal
    @Published var taskFrequency: Task.Frequency = .daily
    @Published var checkpointThresholds: [Int] = [4, 8, 16]
    
    private let firebaseService = FirebaseService.shared
    
    func fetchTasks(nestId: String) async {
        isLoading = true
        if let fetchedTasks = await firebaseService.fetchTasks(nestId: nestId) {
            self.tasks = fetchedTasks
        }
        isLoading = false
    }
    
    func createTask(nestId: String, deserving: [(title: String, description: String)]) async {
        guard !taskName.isEmpty else {
            errorMessage = "Task name is required"
            return
        }
        
        var checkpoints: [Checkpoint] = []
        for (index, threshold) in checkpointThresholds.enumerated() {
            let checkpointId = UUID().uuidString
            let deserv = Deserving(
                id: UUID().uuidString,
                taskId: "", // Will be set by backend
                checkpointOrder: index + 1,
                title: deserving[safe: index]?.title ?? "Reward",
                description: deserving[safe: index]?.description ?? "",
                createdBy: firebaseService.currentPigeon?.id ?? "",
                createdAt: Date()
            )
            checkpoints.append(Checkpoint(
                id: checkpointId,
                taskId: "",
                order: index + 1,
                dayThreshold: threshold,
                deserving: deserv
            ))
        }
        
        let task = await firebaseService.createTask(
            nestId: nestId,
            name: taskName,
            description: taskDescription,
            type: taskType,
            frequency: taskFrequency,
            checkpoints: checkpoints
        )
        
        if task != nil {
            await fetchTasks(nestId: nestId)
            resetForm()
        } else {
            errorMessage = firebaseService.errorMessage ?? "Failed to create task"
        }
    }
    
    func markTaskComplete(taskId: String, pigeonId: String, date: String) async {
        await firebaseService.markTaskComplete(taskId: taskId, pigeonId: pigeonId, date: date, isComplete: true)
    }
    
    private func resetForm() {
        taskName = ""
        taskDescription = ""
        taskType = .personal
        taskFrequency = .daily
        checkpointThresholds = [4, 8, 16]
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
