import SwiftUI

struct NestSetupView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @StateObject private var viewModel = NestViewModel()
    
    var body: some View {
        ZStack {
            SoloLevellingTheme.deepBlack.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Text("CREATE OR JOIN A NEST")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(SoloLevellingTheme.brightGold)
                    .padding(.top, 40)
                
                VStack(spacing: 16) {
                    // Create Nest Button
                    Button(action: { viewModel.showCreateNest = true }) {
                        VStack(spacing: 8) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 32))
                                .foregroundColor(SoloLevellingTheme.brightGold)
                            Text("Create Nest")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(SoloLevellingTheme.silverWhite)
                            Text("Start fresh with your partner")
                                .font(.system(size: 12))
                                .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .themeCard()
                    }
                    
                    // Join Nest Button
                    Button(action: { viewModel.showJoinNest = true }) {
                        VStack(spacing: 8) {
                            Image(systemName: "link")
                                .font(.system(size: 32))
                                .foregroundColor(SoloLevellingTheme.rankC)
                            Text("Join Nest")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(SoloLevellingTheme.silverWhite)
                            Text("Use invite code from partner")
                                .font(.system(size: 12))
                                .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .themeCard()
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Sign Out Button
                Button(action: { firebaseService.signOut() }) {
                    Text("Sign Out")
                        .modifier(ThemeButton(style: .danger))
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $viewModel.showCreateNest) {
            CreateNestSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showJoinNest) {
            JoinNestSheet(viewModel: viewModel)
        }
    }
}

struct CreateNestSheet: View {
    @ObservedObject var viewModel: NestViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            SoloLevellingTheme.darkPurple.ignoresSafeArea()
            
            VStack(spacing: 16) {
                Text("Create Your Nest")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(SoloLevellingTheme.brightGold)
                
                TextField("Nest Name", text: $viewModel.nestName)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(.black)
                
                Picker("Theme", selection: $viewModel.nestTheme) {
                    Text("Dark Purple").tag("dark_purple")
                    Text("Gold & Black").tag("gold_black")
                    Text("Silver & Black").tag("silver_black")
                }
                .pickerStyle(.menu)
                .tint(SoloLevellingTheme.brightGold)
                
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(.system(size: 12))
                        .foregroundColor(SoloLevellingTheme.errorRed)
                }
                
                Button(action: {
                    Task {
                        await viewModel.createNest()
                        dismiss()
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Create Nest")
                    }
                }
                .modifier(ThemeButton(style: .primary))
                .disabled(viewModel.isLoading)
                
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .modifier(ThemeButton(style: .secondary))
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

struct JoinNestSheet: View {
    @ObservedObject var viewModel: NestViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            SoloLevellingTheme.darkPurple.ignoresSafeArea()
            
            VStack(spacing: 16) {
                Text("Join a Nest")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(SoloLevellingTheme.brightGold)
                
                TextField("Invite Code", text: $viewModel.inviteCode)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(.black)
                    .textInputAutocapitalization(.characters)
                
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(.system(size: 12))
                        .foregroundColor(SoloLevellingTheme.errorRed)
                }
                
                Button(action: {
                    Task {
                        await viewModel.joinNest()
                        dismiss()
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Join Nest")
                    }
                }
                .modifier(ThemeButton(style: .primary))
                .disabled(viewModel.isLoading)
                
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .modifier(ThemeButton(style: .secondary))
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    NestSetupView()
        .environmentObject(FirebaseService.shared)
}
