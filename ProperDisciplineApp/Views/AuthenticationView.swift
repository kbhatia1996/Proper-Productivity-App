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
                    Text("PROPER PRODUCTIVE PIGEONS")
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
                            .foregroundColor(.primary)
                        
                        Text("Choose Avatar")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SoloLevellingTheme.silverWhite)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.avatarOptions, id: \.self) { avatar in
                                    Button {
                                        viewModel.selectedAvatar = avatar
                                    } label: {
                                        Text(avatar)
                                            .font(.system(size: 30))
                                            .frame(width: 48, height: 48)
                                            .background(
                                                viewModel.selectedAvatar == avatar
                                                    ? SoloLevellingTheme.brightGold.opacity(0.22)
                                                    : SoloLevellingTheme.silverWhite.opacity(0.08)
                                            )
                                            .clipShape(Circle())
                                            .overlay {
                                                Circle()
                                                    .stroke(
                                                        viewModel.selectedAvatar == avatar
                                                            ? SoloLevellingTheme.brightGold
                                                            : .clear,
                                                        lineWidth: 2
                                                    )
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Choose \(avatar) avatar")
                                    .accessibilityAddTraits(viewModel.selectedAvatar == avatar ? .isSelected : [])
                                }
                            }
                        }
                    }
                    
                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                        .foregroundColor(.primary)
                    
                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(viewModel.isSignUp ? .newPassword : .password)
                        .foregroundColor(.primary)
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
                    _Concurrency.Task {
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
                
                HStack {
                    Rectangle().fill(SoloLevellingTheme.silverWhite.opacity(0.25)).frame(height: 1)
                    Text("or")
                        .font(.system(size: 12))
                        .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.6))
                    Rectangle().fill(SoloLevellingTheme.silverWhite.opacity(0.25)).frame(height: 1)
                }
                .padding(.horizontal)
                
                Button(action: {
                    _Concurrency.Task { await viewModel.signInWithGoogle() }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                        Text("Continue with Google")
                    }
                }
                .modifier(ThemeButton(style: .secondary))
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
