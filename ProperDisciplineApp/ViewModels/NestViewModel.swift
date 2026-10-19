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
    
    func createNest() async {
        isLoading = true
        errorMessage = ""
        
        guard !nestName.isEmpty else {
            errorMessage = "Nest name is required"
            isLoading = false
            return
        }
        
        let nest = await firebaseService.createNest(
            name: nestName,
            theme: nestTheme
        )
        
        if nest == nil {
            errorMessage = firebaseService.errorMessage ?? "Failed to create nest"
        } else {
            showCreateNest = false
            nestName = ""
        }
        
        isLoading = false
    }
    
    func joinNest() async {
        isLoading = true
        errorMessage = ""
        
        guard !inviteCode.isEmpty else {
            errorMessage = "Invite code is required"
            isLoading = false
            return
        }
        
        let nest = await firebaseService.joinNest(inviteCode: inviteCode)
        
        if nest == nil {
            errorMessage = firebaseService.errorMessage ?? "Failed to join nest"
        } else {
            showJoinNest = false
            inviteCode = ""
        }
        
        isLoading = false
    }
}
