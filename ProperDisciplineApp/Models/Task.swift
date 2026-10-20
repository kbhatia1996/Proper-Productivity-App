import Foundation

struct Task: Identifiable, Codable {
    let id: String
    let nestId: String
    let name: String
    let description: String
    let taskType: TaskType  // personal or shared
    let frequency: Frequency  // daily, weekly, custom
    let createdBy: String  // Pigeon ID
    let createdAt: Date
    var updatedAt: Date
    let checkpoints: [Checkpoint]
    var consecutiveDaysCompleted: Int = 0  // Track streak for progress
    
    enum TaskType: String, Codable {
        case personal
        case shared
    }
    
    enum Frequency: String, Codable {
        case daily
        case weekly
        case custom
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case nestId = "nest_id"
        case name, description
        case taskType = "task_type"
        case frequency
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case checkpoints
        case consecutiveDaysCompleted = "consecutive_days_completed"
    }
    
    /// Calculate progress percentage for the current checkpoint
    func getCurrentCheckpointProgress() -> (current: Int, target: Int, percentage: Double) {
        guard !checkpoints.isEmpty else { return (0, 1, 0) }
        let currentCheckpoint = checkpoints[0]
        // Edge case: a zero threshold would divide by zero
        let target = max(1, currentCheckpoint.dayThreshold)
        let percentage = Double(min(consecutiveDaysCompleted, target)) / Double(target) * 100
        return (consecutiveDaysCompleted, target, percentage)
    }
}
