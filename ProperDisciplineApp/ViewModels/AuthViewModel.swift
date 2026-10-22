import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var name = ""
    @Published var selectedAvatar = "🐦"
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var isSignUp = false
    
    private let firebaseService = FirebaseService.shared
    
    let avatarOptions = [
        "🐦", "🕊️", "🐤", "🦜", "🦉", "🦅", "🦆", "🦢",
        "🐧", "🐥", "🦩", "🦚", "🦃", "🐓", "🐣", "🦤",
        "🦇", "🐺", "🦊", "🐱", "🐼", "🐨", "🦋", "🐸"
    ]
    
    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    
    /// Minimal shape check; Firebase does the authoritative validation
    private var emailLooksValid: Bool {
        let parts = trimmedEmail.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".") && !trimmedEmail.contains(" ")
    }
    
    func signUp() async {
        guard !isLoading else { return }   // ignore double taps
        errorMessage = ""
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty, !trimmedName.isEmpty else {
            errorMessage = "All fields are required"
            return
        }
        guard emailLooksValid else {
            errorMessage = "Enter a valid email address"
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        let ok = await firebaseService.signUp(email: trimmedEmail, password: password, name: trimmedName, avatar: selectedAvatar)
        if ok {
            password = ""
        } else {
            errorMessage = firebaseService.errorMessage ?? "Sign up failed"
        }
    }
    
    func signIn() async {
        guard !isLoading else { return }
        errorMessage = ""
        
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required"
            return
        }
        guard emailLooksValid else {
            errorMessage = "Enter a valid email address"
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        let ok = await firebaseService.signIn(email: trimmedEmail, password: password)
        if ok {
            password = ""
        } else {
            errorMessage = firebaseService.errorMessage ?? "Sign in failed"
        }
    }
    
    func signInWithGoogle() async {
        guard !isLoading else { return }
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }
        let ok = await firebaseService.signInWithGoogle(avatar: selectedAvatar)
        if !ok, let message = firebaseService.errorMessage {
            errorMessage = message
        }
    }
    
    func signOut() {
        firebaseService.signOut()
    }
}
