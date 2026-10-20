# Edge Case Scenarios & Handling

This document shows real-world scenarios where the fitness calendar must handle edge cases gracefully.

---

## Scenario 1: User Goes Offline for 3 Days

### Situation
- Oct 10-12: No internet connection
- Oct 13: Reconnects, attempts to sync
- Expected: Calendar shows incomplete data for Oct 10-12

### Data State
```swift
// Oct 9 (online)
TaskCompletion(id: "t1", date: "2026-10-09", isComplete: true)

// Oct 10-12 (MISSING - offline)
// No records synced

// Oct 13 (online)
TaskCompletion(id: "t2", date: "2026-10-13", isComplete: true)
```

### App Behavior

**Detection**:
```swift
private func detectDataGaps() {
    let calendar = Calendar.current
    let today = Date()
    var lastSeenDate: Date? = nil
    
    for day in calendarDays {
        if !day.hasNoData {
            lastSeenDate = day.date
        } else if let lastDate = lastSeenDate {
            let daysBetween = calendar.dateComponents([.day], from: lastDate, to: day.date).day ?? 0
            if daysBetween > 1 {
                hasDataGaps = true  // Gap detected
                return
            }
        }
    }
}
```

**UI Display**:
- Oct 9: Normal progress circle (75%)
- Oct 10-12: Gray circles (no data)
- Oct 13: Normal progress circle (60%)
- **Warning Banner**: "Some days have missing data. Check your sync status."

**User Actions**:
1. Tap warning banner → Opens sync status
2. Manual sync trigger → Attempts to fetch offline records
3. Recovery: If offline records exist locally, they merge on sync

---

## Scenario 2: Both Partners Complete Shared Task on Same Day

### Situation
- Shared task: "Evening Walk"
- Oct 15: Both Pigeon 1 and Pigeon 2 marked "complete"
- Expected: Circle shows 100% shared progress

### Data State
```swift
// Pigeon 1
TaskCompletion(pigeonId: "p1", taskId: "shared_walk", date: "2026-10-15", isComplete: true)

// Pigeon 2
TaskCompletion(pigeonId: "p2", taskId: "shared_walk", date: "2026-10-15", isComplete: true)

// Aggregated for CalendarDayProgress
dayProgress.sharedProgress = 1.0  // 2/2 = 100%
```

**Calculation**:
```swift
// In CalendarViewModel.fetchDayProgress()
let sharedCompletions = [
    TaskCompletion(pigeonId: "p1", isComplete: true),
    TaskCompletion(pigeonId: "p2", isComplete: true)
]

let completed = sharedCompletions.filter { $0.isComplete }.count  // 2
let percentage = Double(completed) / Double(sharedCompletions.count)  // 2/2 = 1.0
dayProgress.sharedProgress = percentage
```

**UI Display**:
```
Oct 15 Circle:
├─ Personal Ring: 75% (blue)
└─ Shared Ring: 100% (gold) ⭐
```

---

## Scenario 3: Task Removed Mid-Period

### Situation
- Oct 1: Task "Read Book" created
- Oct 1-10: Task tracked normally
- Oct 11: Task deleted by user
- Expected: Calendar shows Oct 1-10 progress, Oct 11+ adjusted

### Data State
```swift
// Oct 1-10
TaskCompletion(taskId: "read_book", date: "2026-10-XX", isComplete: true/false)

// Oct 11+ (task deleted)
// No more completions for this task

// Period Summary
TaskPeriodSummary(
    taskId: "read_book",
    completionDays: 7,
    targetDays: 10  // Oct 1-10 only
)
```

**Calculation Safeguard**:
```swift
// Prevents division by zero
var progressPercentage: Double {
    guard targetDays > 0 else { return 0 }  // Edge case: return 0 if no target
    return Double(completionDays) / Double(targetDays) * 100
}
```

**UI Display**:
- Oct 1-10: Normal progress shown
- Oct 11+: Task removed from summaries
- Summary shows: "7/10 days • 70%" with note "Task ended Oct 10"

---

## Scenario 4: Checkpoint Claimed While Partner Offline

### Situation
- Oct 15: Pigeon 1 hits checkpoint for "Exercise" task
- Oct 15: Pigeon 2 still offline
- Expected: Pigeon 1 sees star, Pigeon 2 sees it when online

### Data State
```swift
// Firestore: Checkpoint claim recorded
ClaimedDeserving(
    id: "claim_1",
    taskId: "exercise",
    pigeonId: "p1",
    dateClaimedString: "2026-10-15",
    claimedAt: Date(),
    taskType: .personal
)

// Pigeon 1's local cache (updated)
calendarDays[14].personalCheckpointsClaimed = 1

// Pigeon 2's local cache (stale - not synced yet)
calendarDays[14].personalCheckpointsClaimed = 0  // ❌ Outdated
```

**Resolution Flow**:
```swift
// 1. Pigeon 1 claims checkpoint
firebaseService.recordCheckpointClaim(...)

// 2. Listener detects change in Firestore
db.collection("claimed_deservings")
    .where("taskId", "==", "exercise")
    .where("dateClaimedString", "==", "2026-10-15")
    .addSnapshotListener { snapshot, error in
        // Refresh calendar
        viewModel.loadCalendarData()  // Refetch Oct 15 data
    }

// 3. When Pigeon 2 comes online, listener fires
// 4. Pigeon 2's calendar refreshes to show the star
```

**UI Display**:

*Pigeon 1 immediately sees*:
```
Oct 15 Circle: ⭐ Deserving Unlocked!
Modal shows:
- Personal Goals: 100%
- 1 deserving claimed: "Exercise Checkpoint"
- Reward: "4-hour gaming session"
```

*Pigeon 2 (offline) sees*:
```
Oct 15 Circle: (no star yet)
```

*Pigeon 2 (online, after sync)*:
```
Oct 15 Circle: ⭐ (notification: "Partner claimed a deserving!")
```

---

## Scenario 5: Deserving Claimed Multiple Times

### Situation
- Task: "Meditate" with 4 checkpoints
- Oct 5: Checkpoint 1 → Claim deserving "Massage 1"
- Oct 12: Checkpoint 2 → Claim deserving "Massage 2"
- Oct 19: Checkpoint 3 → Claim deserving "Massage 3"
- Oct 26: Checkpoint 4 → Claim deserving "Massage 4"
- Expected: Star appears on Oct 5, 12, 19, 26 with different rewards

### Data State
```swift
let claimedDeservings = [
    ClaimedDeserving(dateClaimedString: "2026-10-05", deserving: "Massage 1"),
    ClaimedDeserving(dateClaimedString: "2026-10-12", deserving: "Massage 2"),
    ClaimedDeserving(dateClaimedString: "2026-10-19", deserving: "Massage 3"),
    ClaimedDeserving(dateClaimedString: "2026-10-26", deserving: "Massage 4"),
]

// Calendar calculation
for day in calendarDays {
    day.personalCheckpointsClaimed = claimedDeservings
        .filter { $0.dateClaimedString == day.dateString }
        .count
}
```

**Calendar Visuals**:
```
Oct 5 Circle:  ⭐ (1 checkpoint)
Oct 12 Circle: ⭐ (1 checkpoint)
Oct 19 Circle: ⭐ (1 checkpoint)
Oct 26 Circle: ⭐ (1 checkpoint)
```

**Detail Modal for Oct 5**:
```
Personal Goals
- Completion: 100%
- 1 deserving claimed

Meditation (Checkpoint 1)
Reward: 2-hour massage session

[Claim button if not already claimed]
```

**Detail Modal for Oct 26** (final checkpoint):
```
Personal Goals
- Completion: 100%
- 1 deserving claimed

🎉 All Checkpoints Complete!
Meditation (Final Checkpoint)
Reward: Weekend getaway

[Celebrate Animation]
```

---

## Scenario 6: Filter Changes Mid-Month

### Situation
- Oct 1-15: Viewing "Both" goals
- Oct 15: User switches to "Personal" only
- Expected: Shared rings disappear, circles recalculate

### Before Filter Change
```swift
// Oct 15 display
dayProgress = CalendarDayProgress(
    personalProgress: 0.75,
    sharedProgress: 0.90
)

// Circle shows both rings
- Inner (blue): 75%
- Outer (gold): 90%
```

**Filter Change Action**:
```swift
func setFilter(_ filter: FilterMode) {
    viewModel.filterMode = filter
    viewModel.applyFilter()  // Recalculates display
}

// In applyFilter():
func filterPersonalOnly() {
    calendarDays = calendarDays.map { day in
        var filtered = day
        filtered.sharedProgress = 0  // Remove shared ring
        return filtered
    }
}
```

### After Filter Change
```swift
// Oct 15 new display
dayProgress = CalendarDayProgress(
    personalProgress: 0.75,
    sharedProgress: 0  // Filtered out
)

// Circle shows only personal ring
- Inner (blue): 75%
- Outer (gold): 0% (hidden)
```

**UI Animation**:
```
Tap: Personal Goals filter
↓
Gold ring animates out (0.3s)
Summary updates: "Only showing personal tasks"
↓
Calendar refreshes
```

---

## Scenario 7: Timezone Change During Travel

### Situation
- User in UTC timezone
- Oct 15 9:00 AM UTC: Completes task
- 10:00 AM UTC: Travels to PST (UTC-8)
- Expected: Oct 15 still shows as completed, no data loss

### Data Storage (Server)
```swift
// Always stored as ISO8601 UTC
TaskCompletion(
    date: "2026-10-15T09:00:00Z",  // UTC
    createdAt: Date()  // Automatically UTC
)
```

**Client-Side Handling**:
```swift
// When fetching
let dateStr = ISO8601DateFormatter().string(from: date)
// Always returns: "2026-10-15T09:00:00Z"

// When displaying
let displayDate = dateFormatter.string(from: date)
// Converts to local timezone for display
// PST: "October 15, 2026 1:00 AM"
// But date component stays: Oct 15
```

**Result**:
- Completion date: Oct 15 (regardless of timezone)
- Local time displayed: Oct 15 1:00 AM PST
- Calendar: Oct 15 circle shows progress correctly

---

## Scenario 8: First Time User (No Data)

### Situation
- New user account created
- No tasks created yet
- Expected: Calendar shows empty state, prompts to create tasks

### Data State
```swift
let calendarDays: [CalendarDayProgress] = []
let taskSummaries: [TaskPeriodSummary] = []
let claimedDeservings: [ClaimedDeserving] = []
```

**Empty State Detection**:
```swift
if viewModel.taskSummaries.isEmpty {
    // Show empty state
}

if viewModel.calendarDays.allSatisfy({ $0.hasNoData }) {
    // Show empty calendar
}
```

**UI Display**:
```html
<div class="empty-state">
    <div class="empty-state-icon">📋</div>
    <p>No tasks yet. Create your first goal to start tracking.</p>
    <button>Create First Task</button>
</div>
```

**Action**:
- Tap "Create First Task"
- Opens TaskCreationView
- After creation, calendar refreshes with data

---

## Scenario 9: Leap Year February

### Situation
- Feb 2024: Leap year (29 days)
- Feb 2025: Regular year (28 days)
- Expected: Calendar grid adjusts correctly

### Feb 2024 Handling
```swift
let calendar = Calendar.current
let range = calendar.range(of: .day, in: .month, for: Date(timeIntervalSince1970: 1704067200))
// Returns: 1..<30 (29 days, 0-indexed)

let daysInMonth = range.count  // 29
let weekCount = (29 + 6) / 7   // 5 weeks
```

**Feb 2024 Grid**:
```
S  M  T  W  T  F  S
            1  2  3
4  5  6  7  8  9  10
11 12 13 14 15 16 17
18 19 20 21 22 23 24
25 26 27 28 29
```

**Feb 2025 Grid**:
```
S  M  T  W  T  F  S
                   1
2  3  4  5  6  7  8
9  10 11 12 13 14 15
16 17 18 19 20 21 22
23 24 25 26 27 28
```

---

## Scenario 10: Current Month (Incomplete)

### Situation
- Today: Oct 20, 2026
- Viewing: Oct 2026 calendar
- Expected: Months shows "In Progress", can't view Nov

### Detection Logic
```swift
private func detectDataGaps() {
    let today = Date()
    let calendar = Calendar.current
    let isCurrentMonth = calendar.dateComponents([.year, .month], from: today) ==
                        calendar.dateComponents([.year, .month], from: selectedMonth)
    
    if isCurrentMonth {
        let lastDayWithData = calendarDays.last(where: { !$0.hasNoData })?.date
        incompleteMonth = lastDayWithData == nil || lastDayWithData! < today
    }
}
```

**UI Display**:
- Days 1-20: Populated with progress data
- Days 21-31: May be empty or showing "no data" state
- Notice: "Current month is still in progress"
- Next button: Disabled (can't view Nov 2026 yet)

```swift
func canGoToNextMonth() -> Bool {
    let calendar = Calendar.current
    let today = Date()
    if let nextMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
        return nextMonth <= today  // Only allow past/present months
    }
    return false
}
```

---

## Scenario 11: Period Boundary (Dec → Jan)

### Situation
- Viewing: Dec 2025
- Switching to: Jan 2026 quarterly view
- Expected: Q4 2025 data preserved, Q1 2026 starts fresh

### Data Aggregation
```swift
// Q4 2025 ProgressAnalytics
ProgressAnalytics(
    periodType: .quarterly,
    periodStart: Date(2025, 10, 1),  // Oct 1
    periodEnd: Date(2025, 12, 31),   // Dec 31
    completionDays: 87,
    targetDays: 92
)

// Q1 2026 ProgressAnalytics
ProgressAnalytics(
    periodType: .quarterly,
    periodStart: Date(2026, 1, 1),   // Jan 1
    periodEnd: Date(2026, 3, 31),    // Mar 31
    completionDays: 25,              // Jan 25 so far
    targetDays: 31                   // Only Jan counted so far (incomplete)
)
```

**UI Display**:
```
Monthly view (Dec 2025):
Period Summary: "Dec 2025"
- Task A: 28/30 days (93%)
- Task B: 25/30 days (83%)

Quarterly view (Q4 2025):
Period Summary: "Q4 2025"
- Task A: 87/92 days (95%)
- Task B: 79/92 days (86%)

Quarterly view (Q1 2026, current):
Period Summary: "Q1 2026 (In Progress)"
- Task A: 25/31 days (81%)
- Task B: 20/31 days (65%)
⚠️ "Current quarter is still in progress"
```

---

## Scenario 12: Concurrent Actions (Sync Race Condition)

### Situation
- 10:00 AM: Pigeon 1 claims checkpoint
- 10:00 AM (simultaneous): Pigeon 2 also claims same checkpoint
- Expected: Both claims recorded, no data loss

### Resolution
```swift
// Firestore batched writes
let batch = db.batch()

let claim1 = ClaimedDeserving(...)
let claim2 = ClaimedDeserving(...)

batch.setData(claim1.toDictionary(), forDocument: db.collection("claimed_deservings").document())
batch.setData(claim2.toDictionary(), forDocument: db.collection("claimed_deservings").document())

try await batch.commit()  // Atomic write
```

**Result**:
```swift
// Both claims exist
claimedDeservings = [claim1, claim2]

// Calendar day shows both
dayProgress.personalCheckpointsClaimed = 2

// Modal shows both
"2 deservings claimed:
 • Pigeon 1: 4-hour gaming
 • Pigeon 2: 2-hour massage"
```

---

## Summary Table

| Edge Case | Detection | Handling | User Feedback |
|-----------|-----------|----------|---------------|
| Offline days | `hasNoData` flag | Gray circle | Data gap warning |
| Incomplete month | Date comparison | "In Progress" | Notice banner |
| Zero tasks | Empty array | Empty state | Prompt to create |
| Leap year | Calendar API | Auto-adjust grid | Transparent |
| Filter change | Mode switch | Recalculate rings | Animation |
| Timezone shift | ISO8601 storage | UTC conversion | Auto-correct |
| Multiple claims | Counting logic | Show all | Enhanced modal |
| Concurrent writes | Batch updates | Atomic commit | No conflicts |
| Period boundary | Date range checks | Separate aggregates | Clear labels |
| Shared task mismatch | Per-pigeon tracking | Show both | Transparent rings |

---

This comprehensive edge case handling ensures the fitness calendar is robust, user-friendly, and ready for real-world usage.
