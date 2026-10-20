import Foundation

struct Pigeon: Identifiable, Codable {
    let id: String
    let email: String
    let name: String
    let avatar: String  // Avatar emoji/URL
    var totalTasksCompleted: Int = 0  // Track total completions for consistency level
    var nestId: String?
    let createdAt: Date
    var lastActiveAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, email, name, avatar
        case totalTasksCompleted = "total_tasks_completed"
        case nestId = "nest_id"
        case createdAt = "created_at"
        case lastActiveAt = "last_active_at"
    }
    
    init(id: String, email: String, name: String, avatar: String, totalTasksCompleted: Int = 0, nestId: String? = nil, createdAt: Date, lastActiveAt: Date) {
        self.id = id
        self.email = email
        self.name = name
        self.avatar = avatar
        self.totalTasksCompleted = totalTasksCompleted
        self.nestId = nestId
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
    }
    
    // Older profiles have no total_tasks_completed (and carry retired rank/xp fields); decode them anyway
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        email = try c.decode(String.self, forKey: .email)
        name = try c.decode(String.self, forKey: .name)
        avatar = try c.decodeIfPresent(String.self, forKey: .avatar) ?? ""
        totalTasksCompleted = try c.decodeIfPresent(Int.self, forKey: .totalTasksCompleted) ?? 0
        nestId = try c.decodeIfPresent(String.self, forKey: .nestId)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        lastActiveAt = try c.decodeIfPresent(Date.self, forKey: .lastActiveAt) ?? createdAt
    }
    
    /// Calculate consistency level based on total completions
    /// Used for display: "Growing", "Impressive", "Unstoppable", etc.
    var consistencyLevel: String {
        switch totalTasksCompleted {
        case 0..<10: return "Growing"
        case 10..<25: return "Impressive"
        case 25..<50: return "Remarkable"
        case 50..<100: return "Exceptional"
        default: return "Unstoppable"
        }
    }

    var avatarEmoji: String {
        switch avatar {
        case "pigeon_1": return "🐦"
        case "pigeon_2": return "🕊️"
        case "pigeon_3": return "🐤"
        case "pigeon_4": return "🦜"
        default: return avatar.isEmpty ? "🐦" : avatar
        }
    }
}
