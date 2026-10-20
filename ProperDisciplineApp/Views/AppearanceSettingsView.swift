import SwiftUI
import UIKit

struct AppearanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var firebaseService: FirebaseService
    @ObservedObject var taskViewModel: TaskViewModel

    @AppStorage("appAppearance") private var appAppearance = "dark"
    @AppStorage("rewardRemindersEnabled") private var rewardRemindersEnabled = false
    @State private var notificationMessage: String?
    @State private var preserveNotificationMessageWhenDisabling = false

    var body: some View {
        ZStack {
            SoloLevellingTheme.deepBlack.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Settings")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(SoloLevellingTheme.brightGold)
                    Spacer()
                    Button("Done") { dismiss() }
                        .foregroundColor(SoloLevellingTheme.brightGold)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("Appearance", systemImage: "circle.lefthalf.filled")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(SoloLevellingTheme.silverWhite)
                    Picker("Appearance", selection: $appAppearance) {
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                    }
                    .pickerStyle(.segmented)
                    .tint(SoloLevellingTheme.brightGold)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $rewardRemindersEnabled) {
                        Label("Reward reminders", systemImage: "bell.badge")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .tint(SoloLevellingTheme.brightGold)

                    Text("Get one encouraging reminder at 7 PM when a deserving is one check-in away.")
                        .font(.system(size: 13))
                        .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))

                    if let notificationMessage {
                        Text(notificationMessage)
                            .font(.system(size: 13))
                            .foregroundColor(SoloLevellingTheme.errorRed)
                        if notificationMessage.contains("iOS Settings") {
                            Button("Open iOS Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    openURL(url)
                                }
                            }
                            .foregroundColor(SoloLevellingTheme.brightGold)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .onChange(of: rewardRemindersEnabled) { isEnabled in
            _Concurrency.Task { @MainActor in
                guard isEnabled else {
                    RewardNotificationService.shared.cancelUpcomingReminder()
                    if preserveNotificationMessageWhenDisabling {
                        preserveNotificationMessageWhenDisabling = false
                    } else {
                        notificationMessage = nil
                    }
                    return
                }
                notificationMessage = nil

                do {
                    let isAuthorized = try await RewardNotificationService.shared.requestAuthorization()
                    guard isAuthorized else {
                        preserveNotificationMessageWhenDisabling = true
                        rewardRemindersEnabled = false
                        notificationMessage = "Allow notifications in iOS Settings to turn on reward reminders."
                        return
                    }
                    guard let pigeonId = firebaseService.currentPigeon?.id else { return }
                    try await RewardNotificationService.shared.refreshUpcomingReminder(
                        tasks: taskViewModel.tasks,
                        pigeonId: pigeonId
                    )
                    notificationMessage = nil
                } catch {
                    preserveNotificationMessageWhenDisabling = true
                    rewardRemindersEnabled = false
                    notificationMessage = error.localizedDescription
                }
            }
        }
    }
}
