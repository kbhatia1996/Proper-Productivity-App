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
    }
}
