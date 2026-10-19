import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var name = ""
    @Published var selectedAvatar = "pigeon_1"
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var isSignUp = false
    
    private let firebaseService = FirebaseService.shared
    
    let avatarOptions = ["pigeon_1", "pigeon_2", "pigeon_3", "pigeon_4"]
    
    func signUp() async {
        isLoading = true
        errorMessage = ""
        
        guard !email.isEmpty, !password.isEmpty, !name.isEmpty else {
            errorMessage = "All fields are required"
            isLoading = false
            return
        }
        
        await firebaseService.signUp(
            email: email,
            password: password,
            name: name,
            avatar: selectedAvatar
        )
        
        if firebaseService.errorMessage != nil {
            errorMessage = firebaseService.errorMessage ?? "Sign up failed"
        }
        
        isLoading = false
    }
    
    func signIn() async {
        isLoading = true
        errorMessage = ""
        
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required"
            isLoading = false
            return
        }
        
        await firebaseService.signIn(email: email, password: password)
        
        if firebaseService.errorMessage != nil {
            errorMessage = firebaseService.errorMessage ?? "Sign in failed"
        }
        
        isLoading = false
    }
    
    func signOut() {
        firebaseService.signOut()
    }
}
