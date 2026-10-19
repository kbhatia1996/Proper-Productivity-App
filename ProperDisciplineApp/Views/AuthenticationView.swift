import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background
            SoloLevellingTheme.deepBlack.ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text("PROPER DISCIPLINE")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(SoloLevellingTheme.brightGold)
                    Text("Couples' Leveling System")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
                }
                .padding(.top, 40)
                
                // Toggle Sign Up / Sign In
                Picker("Mode", selection: $viewModel.isSignUp) {
                    Text("Sign In").tag(false)
                    Text("Sign Up").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .tint(SoloLevellingTheme.brightGold)
                
                // Form
                VStack(spacing: 16) {
                    if viewModel.isSignUp {
                        TextField("Name", text: $viewModel.name)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(.black)
                        
                        Text("Choose Avatar")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SoloLevellingTheme.silverWhite)
                        
                        HStack(spacing: 12) {
                            ForEach(viewModel.avatarOptions, id: \.self) { avatar in
                                VStack {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(viewModel.selectedAvatar == avatar ? SoloLevellingTheme.brightGold : SoloLevellingTheme.rankE)
                                    Text(avatar)
                                        .font(.system(size: 10))
                                        .foregroundColor(SoloLevellingTheme.silverWhite)
                                }
                                .onTapGesture {
                                    viewModel.selectedAvatar = avatar
                                }
                            }
                        }
                    }
                    
                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .foregroundColor(.black)
                    
                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(.black)
                }
                .padding(.horizontal)
                
                // Error Message
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(.system(size: 12))
                        .foregroundColor(SoloLevellingTheme.errorRed)
                        .padding()
                        .background(SoloLevellingTheme.errorRed.opacity(0.1))
                        .cornerRadius(SoloLevellingTheme.cornerRadius)
                        .padding(.horizontal)
                }
                
                // Submit Button
                Button(action: {
                    Task {
                        if viewModel.isSignUp {
                            await viewModel.signUp()
                        } else {
                            await viewModel.signIn()
                        }
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(SoloLevellingTheme.deepBlack)
                    } else {
                        Text(viewModel.isSignUp ? "Create Account" : "Sign In")
                    }
                }
                .modifier(ThemeButton(style: .primary))
                .disabled(viewModel.isLoading)
                .padding(.horizontal)
                
                Spacer()
            }
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthViewModel())
}
