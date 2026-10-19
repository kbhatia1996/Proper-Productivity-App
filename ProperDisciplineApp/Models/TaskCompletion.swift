import Foundation

struct TaskCompletion: Identifiable, Codable {
    let id: String
    let taskId: String
    let pigeonId: String
    let date: String  // YYYY-MM-DD format
    let isComplete: Bool
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case pigeonId = "pigeon_id"
        case date
        case isComplete = "is_complete"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: String = UUID().uuidString, taskId: String, pigeonId: String, date: String, isComplete: Bool) {
        self.id = id
        self.taskId = taskId
        self.pigeonId = pigeonId
        self.date = date
        self.isComplete = isComplete
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct Streak: Identifiable, Codable {
    let id: String
    let taskId: String
    let pigeonId: String
    var currentCount: Int = 0
    var lastCompletionDate: String  // YYYY-MM-DD
    var resetDate: String?  // When the streak was last broken
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case pigeonId = "pigeon_id"
        case currentCount = "current_count"
        case lastCompletionDate = "last_completion_date"
        case resetDate = "reset_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
