import SwiftUI
import FirebaseCore

@main
struct ProperDisciplineAppApp: App {
    /// False when GoogleService-Info.plist wasn't bundled; we show a setup screen instead of crashing.
    private let firebaseConfigured: Bool
    @AppStorage("appAppearance") private var appAppearance = "dark"
    
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            firebaseConfigured = true
        } else {
            firebaseConfigured = false
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !firebaseConfigured {
                    FirebaseSetupMissingView()
                } else if firebaseService.isAuthenticated {
                    if firebaseService.currentPigeon == nil {
                        // Avoids flashing the nest setup screen while the profile loads
                        LoadingProfileView()
                            .environmentObject(firebaseService)
                    } else if firebaseService.currentPigeon?.nestId != nil {
                        // User is in a nest: Home + Activity calendar tabs
                        MainTabView()
                            .environmentObject(firebaseService)
                    } else {
                        // Signed in but still needs to create or join a nest
                        NestSetupView()
                            .environmentObject(firebaseService)
                    }
                } else {
                    AuthenticationView()
                        .environmentObject(authViewModel)
                }
            }
            .preferredColorScheme(appAppearance == "light" ? .light : .dark)
            .overlay(alignment: .topTrailing) {
                if !firebaseService.isAuthenticated || firebaseService.currentPigeon?.nestId == nil {
                    Button {
                        appAppearance = appAppearance == "dark" ? "light" : "dark"
                    } label: {
                        Image(systemName: appAppearance == "dark" ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(SoloLevellingTheme.brightGold)
                            .padding(10)
                            .background(SoloLevellingTheme.darkPurple)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(appAppearance == "dark" ? "Switch to light appearance" : "Switch to dark appearance")
                    .padding()
                }
            }
            .onChange(of: firebaseService.isAuthenticated) { isAuthenticated in
                if !isAuthenticated {
                    _Concurrency.Task { @MainActor in
                        RewardNotificationService.shared.cancelUpcomingReminder()
                    }
                }
            }
        }
    }
}

struct FirebaseSetupMissingView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(SoloLevellingTheme.warningOrange)
            Text("Firebase isn't configured")
                .font(.system(size: 18, weight: .bold))
            Text("Add GoogleService-Info.plist to the app target and rebuild. See INSTALL_ON_IPHONE.md.")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

struct LoadingProfileView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading your profile…")
                .font(.system(size: 13))
            if let error = firebaseService.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(SoloLevellingTheme.errorRed)
                    .multilineTextAlignment(.center)
            }
            // Escape hatch if the profile can't be loaded (offline, missing document)
            Button("Sign Out") { firebaseService.signOut() }
                .font(.system(size: 13))
        }
        .padding(32)
    }
}
