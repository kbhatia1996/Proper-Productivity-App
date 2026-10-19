import Foundation

struct Pigeon: Identifiable, Codable {
    let id: String
    let email: String
    let name: String
    let avatar: String  // Avatar name/URL
    var xp: Int = 0
    var rank: String = "E"  // Solo Levelling ranks: E, D, C, B, A, S
    var nestId: String?
    let createdAt: Date
    var lastActiveAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, email, name, avatar, xp, rank
        case nestId = "nest_id"
        case createdAt = "created_at"
        case lastActiveAt = "last_active_at"
    }
    
    /// Calculate rank based on XP (adjust thresholds as needed)
    static func rankFromXP(_ xp: Int) -> String {
        switch xp {
        case 0..<100: return "E"
        case 100..<300: return "D"
        case 300..<600: return "C"
        case 600..<1000: return "B"
        case 1000..<1500: return "A"
        default: return "S"
        }
    }
}
