import Foundation

/// Stores historical progress data for analytics & time-period views
struct ProgressAnalytics: Identifiable, Codable {
    let id: String
    let taskId: String
    let pigeonId: String
    let periodType: PeriodType
    let periodStart: Date
    let periodEnd: Date
    
    var completionDays: Int  // Actual days completed
    var targetDays: Int      // Expected days in period
    var checkpointsClaimed: Int
    var isEmpty: Bool {
        completionDays == 0 && checkpointsClaimed == 0
    }
    
    enum PeriodType: String, Codable {
        case daily
        case weekly
        case monthly
        case quarterly
        case yearly
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case pigeonId = "pigeon_id"
        case periodType = "period_type"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case completionDays = "completion_days"
        case targetDays = "target_days"
        case checkpointsClaimed = "checkpoints_claimed"
    }
    
    /// Calculate progress percentage for the period
    var progressPercentage: Double {
        guard targetDays > 0 else { return 0 }
        return Double(completionDays) / Double(targetDays) * 100
    }
    
    /// Determine circle color based on progress
    var circleColor: String {
        let percentage = progressPercentage
        switch percentage {
        case 0:
            return "gray"  // Not started
        case 0..<25:
            return "red"   // Struggling
        case 25..<50:
            return "orange" // Moderate
        case 50..<75:
            return "yellow" // Good
        case 75..<100:
            return "lightGreen"  // Excellent
        default:
            return "green"  // Perfect
        }
    }
}

/// One day on the calendar. Raw values are kept per type so any filter can be applied without losing data.
struct CalendarDayProgress: Identifiable {
    let id: String
    let date: Date
    let dayOfWeek: Int  // 1-7 (Sunday to Saturday)
    let dayOfMonth: Int
    
    // Scheduled check-ins and (fractional) completions per type
    var personalScheduled: Int = 0
    var sharedScheduled: Int = 0
    var personalDone: Double = 0
    var sharedDone: Double = 0
    var isFuture: Bool = false
    
    var personalCheckpointsClaimed: Int = 0
    var sharedCheckpointsClaimed: Int = 0
    
    /// 0-1.0 ring values. Division by zero is impossible: nothing scheduled -> 0.
    var personalProgress: Double {
        personalScheduled > 0 ? min(1, personalDone / Double(personalScheduled)) : 0
    }
    var sharedProgress: Double {
        sharedScheduled > 0 ? min(1, sharedDone / Double(sharedScheduled)) : 0
    }
    var combinedProgress: Double {
        let total = personalScheduled + sharedScheduled
        return total > 0 ? min(1, (personalDone + sharedDone) / Double(total)) : 0
    }
    
    var hasPersonalCompletion: Bool { personalProgress > 0 }
    var hasSharedCompletion: Bool { sharedProgress > 0 }
    var anyCompletion: Bool { hasPersonalCompletion || hasSharedCompletion }
    
    /// Edge case: nothing was scheduled (before the first task existed, rest day, or filtered out)
    var hasNoData: Bool {
        personalScheduled == 0 && sharedScheduled == 0
    }
    
    /// Copy with one side removed, used by the Personal / Shared filters
    func filtered(includePersonal: Bool, includeShared: Bool) -> CalendarDayProgress {
        var copy = self
        if !includePersonal {
            copy.personalScheduled = 0
            copy.personalDone = 0
            copy.personalCheckpointsClaimed = 0
        }
        if !includeShared {
            copy.sharedScheduled = 0
            copy.sharedDone = 0
            copy.sharedCheckpointsClaimed = 0
        }
        return copy
    }
}

/// Aggregated month ring used by the quarterly and yearly views
struct MonthTile: Identifiable {
    let id: String
    let monthStart: Date
    let personalProgress: Double
    let sharedProgress: Double
    let combinedProgress: Double
    let hasData: Bool
    let isFuture: Bool
}

/// Metadata about task progress for a specific time period
struct TaskPeriodSummary: Identifiable {
    let id: String
    let taskId: String
    let taskName: String
    let taskType: String  // "personal" or "shared"
    let periodType: String  // "weekly", "monthly", etc.
    
    var completionDays: Int
    var targetDays: Int
    var checkpointsClaimed: Int
    var streakDays: Int
    var maxStreakInPeriod: Int
    
    var progressPercentage: Double {
        guard targetDays > 0 else { return 0 }
        return Double(completionDays) / Double(targetDays) * 100
    }
    
    /// Edge case tracking
    var isFirstPeriod: Bool = false
    var hasNoHistory: Bool = false
    var isIncomplete: Bool = false  // Period still in progress
}

/// A deserving (reward) a pigeon claimed on a given day. Stored so history survives each cycle reset.
struct ClaimedDeserving: Identifiable, Codable {
    let id: String
    let taskId: String
    let deserving: Deserving
    let pigeonId: String
    let dateClaimedString: String  // YYYY-MM-DD
    let claimedAt: Date
    let taskType: Task.TaskType
    
    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case deserving
        case pigeonId = "pigeon_id"
        case dateClaimedString = "date_claimed"
        case claimedAt = "claimed_at"
        case taskType = "task_type"
    }
}
