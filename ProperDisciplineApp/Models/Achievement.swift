import Foundation

struct Achievement: Identifiable, Codable {
    let id: String
    let nestId: String
    let pigeonId: String
    let type: AchievementType
    let title: String
    let description: String
    let unlockedAt: Date
    
    enum AchievementType: String, Codable {
        case checkpoint_unlock      // Hit a checkpoint
        case weekly_perfect         // 7/7 days all tasks
        case couple_milestone       // Both pigeons hit checkpoint together
        case consistency_streak     // Consistency milestone reached
        case first_deserving        // First deserving claimed
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case nestId = "nest_id"
        case pigeonId = "pigeon_id"
        case type, title, description
        case unlockedAt = "unlocked_at"
    }
}
