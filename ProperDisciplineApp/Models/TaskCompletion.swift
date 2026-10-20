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
    
    // Tolerates documents without an id field: the id is always taskId_pigeonId_date
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        taskId = try c.decode(String.self, forKey: .taskId)
        pigeonId = try c.decode(String.self, forKey: .pigeonId)
        date = try c.decode(String.self, forKey: .date)
        isComplete = try c.decodeIfPresent(Bool.self, forKey: .isComplete) ?? false
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? "\(taskId)_\(pigeonId)_\(date)"
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
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
