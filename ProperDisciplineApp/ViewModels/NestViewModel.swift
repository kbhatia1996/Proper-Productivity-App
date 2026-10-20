import SwiftUI

@MainActor
class NestViewModel: ObservableObject {
    @Published var nestName = ""
    @Published var nestTheme = "dark_purple"
    @Published var inviteCode = ""
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showCreateNest = false
    @Published var showJoinNest = false
    
    private let firebaseService = FirebaseService.shared
    
    let themeOptions = ["dark_purple", "gold_black", "silver_black"]
    
    /// Returns true when the nest was created so the sheet knows whether to close
    @discardableResult
    func createNest() async -> Bool {
        guard !isLoading else { return false }
        errorMessage = ""
        
        let name = nestName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Nest name is required"
            return false
        }
        
        isLoading = true
        defer { isLoading = false }
        guard await firebaseService.createNest(name: name, theme: nestTheme) != nil else {
            errorMessage = firebaseService.errorMessage ?? "Failed to create nest"
            return false
        }
        showCreateNest = false
        nestName = ""
        return true
    }
    
    @discardableResult
    func joinNest() async -> Bool {
        guard !isLoading else { return false }
        errorMessage = ""
        
        guard !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Invite code is required"
            return false
        }
        
        isLoading = true
        defer { isLoading = false }
        guard await firebaseService.joinNest(inviteCode: inviteCode) != nil else {
            errorMessage = firebaseService.errorMessage ?? "Failed to join nest"
            return false
        }
        showJoinNest = false
        inviteCode = ""
        return true
    }
}
