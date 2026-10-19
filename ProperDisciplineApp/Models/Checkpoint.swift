import Foundation

struct Checkpoint: Identifiable, Codable {
    let id: String
    let taskId: String
    let order: Int  // 1, 2, 3...
    let dayThreshold: Int  // Days required to hit this checkpoint
    let deserving: Deserving
    
    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case order
        case dayThreshold = "day_threshold"
        case deserving
    }
}

struct Deserving: Identifiable, Codable {
    let id: String
    let taskId: String
    let checkpointOrder: Int
    let title: String  // e.g., "4-hour gaming session"
    let description: String
    let createdBy: String  // Pigeon ID
    var claimedBy: [String] = []  // Pigeon IDs who've earned this
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case checkpointOrder = "checkpoint_order"
        case title, description
        case createdBy = "created_by"
        case claimedBy = "claimed_by"
        case createdAt = "created_at"
    }
}
