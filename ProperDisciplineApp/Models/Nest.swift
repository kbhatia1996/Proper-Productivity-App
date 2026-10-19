import Foundation

struct Nest: Identifiable, Codable {
    let id: String
    let name: String
    let theme: String  // e.g., "dark_purple", "gold_black"
    let createdBy: String  // Pigeon ID
    let pigeons: [String]  // Array of Pigeon IDs
    let inviteCode: String
    let inviteExpiresAt: Date
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, theme
        case createdBy = "created_by"
        case pigeons
        case inviteCode = "invite_code"
        case inviteExpiresAt = "invite_expires_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    /// Check if invite code is still valid
    var isInviteValid: Bool {
        return Date() < inviteExpiresAt
    }
}
