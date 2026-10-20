import Foundation
import UserNotifications

private final class RewardNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

enum RewardReminderError: LocalizedError {
    case failedToLoadProgress(String)
    case notificationsDisabled

    var errorDescription: String? {
        switch self {
        case .failedToLoadProgress(let message):
            return "Couldn't check reward progress: \(message)"
        case .notificationsDisabled:
            return "Notifications are disabled for Proper Productive Pigeons. Enable them in iOS Settings to receive reward reminders."
        }
    }
}

@MainActor
final class RewardNotificationService {
    static let shared = RewardNotificationService()

    private let center = UNUserNotificationCenter.current()
    private let notificationDelegate = RewardNotificationDelegate()
    private let reminderIdentifier = "upcoming-deservings-reminder"
    private var refreshGeneration = 0

    private init() {
        center.delegate = notificationDelegate
    }

    func requestAuthorization() async throws -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return try await center.requestAuthorization(options: [.alert, .sound])
        @unknown default:
            return false
        }
    }

    func cancelUpcomingReminder() {
        refreshGeneration += 1
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }

    func refreshUpcomingReminder(tasks: [Task], pigeonId: String) async throws {
        refreshGeneration += 1
        let generation = refreshGeneration
        guard UserDefaults.standard.bool(forKey: "rewardRemindersEnabled") else {
            center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
            return
        }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral else {
            guard generation == refreshGeneration else { return }
            center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
            throw RewardReminderError.notificationsDisabled
        }

        var upcomingRewards: [(task: String, reward: String)] = []
        for task in tasks where task.taskType == .shared || task.createdBy == pigeonId {
            guard let completions = await FirebaseService.shared.fetchCompletions(
                taskId: task.id,
                pigeonId: pigeonId
            ) else {
                guard generation == refreshGeneration else { return }
                center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
                throw RewardReminderError.failedToLoadProgress(
                    FirebaseService.shared.errorMessage ?? "Please try again."
                )
            }

            let completedCount = completions.filter(\.isComplete).count
            guard let nextCheckpoint = task.checkpoints
                .sorted(by: { $0.order < $1.order })
                .first(where: { $0.dayThreshold > completedCount }),
                  nextCheckpoint.dayThreshold - completedCount == 1 else {
                continue
            }
            upcomingRewards.append((task.name, nextCheckpoint.deserving.title))
        }

        guard generation == refreshGeneration else { return }
        guard !upcomingRewards.isEmpty else {
            center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
            return
        }

        let content = UNMutableNotificationContent()
        content.title = upcomingRewards.count == 1
            ? "Your next reward is close!"
            : "Your rewards are within reach!"
        if let reward = upcomingRewards.first, upcomingRewards.count == 1 {
            content.body = "Just one more check-in for \(reward.task) unlocks \(reward.reward). You've got this!"
        } else {
            content.body = "\(upcomingRewards.count) deservings are one check-in away. Complete a task today and keep your momentum going!"
        }
        content.sound = .default

        var reminderTime = DateComponents()
        reminderTime.hour = 19
        reminderTime.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: reminderTime, repeats: true)
        let request = UNNotificationRequest(
            identifier: reminderIdentifier,
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }
}
