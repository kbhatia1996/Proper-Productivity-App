import SwiftUI

@main
struct ProperDisciplineAppApp: App {
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            if firebaseService.isAuthenticated {
                if firebaseService.currentPigeon?.nestId != nil {
                    // User is in a nest, show dashboard
                    DashboardView()
                        .environmentObject(firebaseService)
                } else {
                    // User is authenticated but needs to create/join a nest
                    NestSetupView()
                        .environmentObject(firebaseService)
                }
            } else {
                // Not authenticated, show login
                AuthenticationView()
                    .environmentObject(authViewModel)
            }
        }
    }
}
