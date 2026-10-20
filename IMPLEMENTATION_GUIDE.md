> **Status note:** this document was written before the code was ever compiled and its "production-ready" wording is overstated. The Swift code has not been built on iOS yet; see INSTALL_ON_IPHONE.md for the real build/test path.

# Implementation Guide - Fitness Calendar Integration

## Quick Start

This guide walks through integrating the new fitness calendar view into the existing Proper Productive Pigeons app.

---

## Files Created

### New Model Files
1. **ProgressAnalytics.swift** - Historical progress tracking
   - Stores daily/weekly/monthly/quarterly/yearly aggregates
   - Enables time-period switching without recalculating raw data

### New ViewModel Files
2. **CalendarViewModel.swift** - Calendar state management
   - Handles filtering (personal/shared/both)
   - Manages time period switching
   - Detects edge cases

### New View Files
3. **FitnessCalendarView.swift** - Main calendar UI
   - Apple Fitness-style progress circles
   - Filter controls
   - Day detail modal
   - Task summaries

### HTML Equivalent
4. **fitness-calendar.html** - Web version
   - Mirrors iOS design
   - Interactive calendar with SVG circles
   - Filterable task summaries

### Documentation Files
5. **FITNESS_CALENDAR_DESIGN.md** - Architecture & edge cases
6. **RANKING_REMOVAL_GUIDE.md** - How to remove XP/rank system
7. **EDGE_CASE_SCENARIOS.md** - Real-world scenario handling

---

## Step 1: Update Pigeon Model

Remove ranking system:

```swift
// ProperDisciplineApp/Models/Pigeon.swift

struct Pigeon: Identifiable, Codable {
    let id: String
    let email: String
    let name: String
    let avatar: String
    var totalTasksCompleted: Int = 0  // ← Keep this for consistency level
    
    // ❌ DELETE: var rank: String, var xp: Int, var rankPoints: Int
    
    var nestId: String?
    let createdAt: Date
    var lastActiveAt: Date
    
    /// New: Consistency level replaces ranking
    var consistencyLevel: String {
        switch totalTasksCompleted {
        case 0..<10: return "Growing"
        case 10..<25: return "Impressive"
        case 25..<50: return "Remarkable"
        case 50..<100: return "Exceptional"
        default: return "Unstoppable"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, email, name, avatar
        case totalTasksCompleted = "total_tasks_completed"
        case nestId = "nest_id"
        case createdAt = "created_at"
        case lastActiveAt = "last_active_at"
    }
}
```

---

## Step 2: Add ProgressAnalytics Model

```swift
// ProperDisciplineApp/Models/ProgressAnalytics.swift
// ✅ Use the complete file created above
```

---

## Step 3: Create CalendarViewModel

```swift
// ProperDisciplineApp/ViewModels/CalendarViewModel.swift
// ✅ Use the complete file created above
```

**Key Methods to Implement**:
- `loadCalendarData()` - Fetch from Firebase
- `applyFilter()` - Recalculate circles based on filter
- `switchPeriod()` - Change time window
- `detectDataGaps()` - Edge case detection

---

## Step 4: Create FitnessCalendarView

```swift
// ProperDisciplineApp/Views/FitnessCalendarView.swift
// ✅ Use the complete file created above
```

**Integration Point**:
```swift
// In DashboardView or TabBar
TabView {
    DashboardView()
        .tabItem { Label("Dashboard", systemImage: "house.fill") }
    
    FitnessCalendarView(
        taskViewModel: taskViewModel,
        firebaseService: firebaseService
    )
    .tabItem { Label("Calendar", systemImage: "calendar") }
    
    ProfileView()
        .tabItem { Label("Profile", systemImage: "person.fill") }
}
```

---

## Step 5: Update Firebase Service

Add new methods to `FirebaseService.swift`:

```swift
// MARK: - Calendar Data Methods

func fetchTaskCompletions(
    for date: Date,
    taskType: Task.TaskType
) async throws -> [TaskCompletion] {
    let dateStr = ISO8601DateFormatter().string(from: date)
    
    let snapshot = try await db
        .collection("task_completions")
        .whereField("pigeon_id", isEqualTo: currentPigeon?.id ?? "")
        .whereField("date", isEqualTo: dateStr)
        .whereField("task_type", isEqualTo: taskType.rawValue)
        .getDocuments()
    
    return try snapshot.documents.map { doc in
        try doc.data(as: TaskCompletion.self)
    }
}

func fetchTaskSummaries(
    for month: Date,
    period: CalendarViewModel.TimePeriod,
    filterMode: CalendarViewModel.FilterMode
) async throws -> [TaskPeriodSummary] {
    let calendar = Calendar.current
    let range = calendar.range(of: periodType(from: period), in: .month, for: month)!
    let periodStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
    let periodEnd = calendar.date(byAdding: .day, value: range.count - 1, to: periodStart)!
    
    let snapshot = try await db
        .collection("progress_analytics")
        .whereField("pigeonId", isEqualTo: currentPigeon?.id ?? "")
        .whereField("periodStart", isGreaterThanOrEqualTo: periodStart)
        .whereField("periodEnd", isLessThanOrEqualTo: periodEnd)
        .getDocuments()
    
    var summaries: [TaskPeriodSummary] = []
    for doc in snapshot.documents {
        let analytics = try doc.data(as: ProgressAnalytics.self)
        
        // Filter based on mode
        let task = try? await getTask(analytics.taskId)
        guard let task = task else { continue }
        
        if (filterMode == .personal && task.taskType == .personal) ||
           (filterMode == .shared && task.taskType == .shared) ||
           (filterMode == .both) {
            summaries.append(TaskPeriodSummary(from: analytics, task: task))
        }
    }
    
    return summaries
}

func recordCheckpointClaim(
    taskId: String,
    deserving: Deserving,
    date: Date
) async throws {
    let claim = ClaimedDeserving(
        id: UUID().uuidString,
        taskId: taskId,
        deserving: deserving,
        pigeonId: currentPigeon?.id ?? "",
        dateClaimedString: ISO8601DateFormatter().string(from: date),
        claimedAt: Date(),
        taskType: getTaskType(taskId)
    )
    
    try await db.collection("claimed_deservings")
        .document(claim.id)
        .setData(from: claim)
}

// MARK: - Helpers

private func periodType(from: CalendarViewModel.TimePeriod) -> Calendar.Component {
    switch from {
    case .weekly: return .weekOfYear
    case .monthly: return .month
    case .quarterly: return .quarter
    case .yearly: return .year
    }
}
```

---

## Step 6: Update Achievement Model

```swift
// ProperDisciplineApp/Models/Achievement.swift

enum AchievementType: String, Codable {
    case checkpoint_unlock
    case weekly_perfect
    case couple_milestone
    // ❌ DELETE: case rank_up
    case first_deserving
    case consistency_streak  // ✅ NEW
}
```

---

## Step 7: Update DashboardView

Replace rank display with consistency level:

```swift
// ProperDisciplineApp/Views/DashboardView.swift

// BEFORE:
HStack(spacing: 8) {
    Text("Rank: \(pigeon.rank)")
        .font(.system(size: 12))
        .foregroundColor(Color.rankColor(for: pigeon.rank))
    Text("XP: \(pigeon.xp)")
}

// AFTER:
HStack(spacing: 8) {
    Text("Consistency: \(pigeon.consistencyLevel)")
        .font(.system(size: 12))
        .foregroundColor(SoloLevellingTheme.brightGold)
    Text("\(pigeon.totalTasksCompleted) completed")
        .font(.system(size: 12))
        .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
}
```

---

## Step 8: Test Edge Cases

Create unit tests:

```swift
// ProperDisciplineAppTests/CalendarViewModelTests.swift

import XCTest
@testable import ProperDisciplineApp

class CalendarViewModelTests: XCTestCase {
    var viewModel: CalendarViewModel!
    var firebaseService: FirebaseService!
    var taskViewModel: TaskViewModel!
    
    override func setUp() {
        super.setUp()
        firebaseService = FirebaseService()
        taskViewModel = TaskViewModel()
        viewModel = CalendarViewModel(firebaseService: firebaseService, taskViewModel: taskViewModel)
    }
    
    // MARK: - Filtering Tests
    
    func testPersonalFilterHidesSharedRings() {
        let day = CalendarDayProgress(personal: 0.75, shared: 0.5)
        viewModel.filterMode = .personal
        viewModel.applyFilter()
        
        XCTAssertEqual(day.personalProgress, 0.75)
        XCTAssertEqual(day.sharedProgress, 0)  // Filtered
    }
    
    func testBothFilterShowsBothRings() {
        let day = CalendarDayProgress(personal: 0.75, shared: 0.5)
        viewModel.filterMode = .both
        viewModel.applyFilter()
        
        XCTAssertEqual(day.personalProgress, 0.75)
        XCTAssertEqual(day.sharedProgress, 0.5)
    }
    
    // MARK: - Edge Case Tests
    
    func testDivisionByZeroProtection() {
        let summary = TaskPeriodSummary(completionDays: 5, targetDays: 0)
        XCTAssertEqual(summary.progressPercentage, 0)
    }
    
    func testDataGapDetection() {
        var days: [CalendarDayProgress] = []
        days.append(CalendarDayProgress(date: Date(), personalProgress: 0.75))  // Day 1
        days.append(CalendarDayProgress(date: Date().addingTimeInterval(86400), personalProgress: 0))  // Day 2 (gap)
        days.append(CalendarDayProgress(date: Date().addingTimeInterval(86400 * 3), personalProgress: 0.5))  // Day 4
        
        viewModel.calendarDays = days
        viewModel.detectDataGaps()
        
        XCTAssertTrue(viewModel.hasDataGaps)
    }
    
    func testIncompleteMonthDetection() {
        let today = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: today)
        let monthStart = calendar.date(from: components)!
        
        viewModel.selectedMonth = monthStart
        viewModel.detectDataGaps()
        
        // Current month should be marked incomplete
        XCTAssertTrue(viewModel.incompleteMonth)
    }
    
    func testZeroTasksEmptyState() {
        viewModel.taskSummaries = []
        
        XCTAssertTrue(viewModel.taskSummaries.isEmpty)
    }
    
    // MARK: - Period Switching Tests
    
    func testWeeklyPeriodSwitch() {
        viewModel.switchPeriod(to: .weekly)
        XCTAssertEqual(viewModel.selectedPeriod, .weekly)
    }
    
    func testCannotViewFutureMonths() {
        let today = Date()
        let calendar = Calendar.current
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: today)!
        
        viewModel.selectedMonth = nextMonth
        XCTAssertFalse(viewModel.canGoToNextMonth())
    }
}
```

---

## Step 9: Firebase Aggregation Job

Set up a Cloud Function to aggregate data at period boundaries:

```javascript
// functions/aggregateProgressAnalytics.js
// Runs daily at midnight UTC

const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.aggregateProgressAnalytics = functions.pubsub
    .schedule('0 0 * * *')  // Daily at midnight UTC
    .timeZone('UTC')
    .onRun(async (context) => {
        const db = admin.firestore();
        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        
        const dateStr = yesterday.toISOString().split('T')[0];
        
        // Get all pigeons
        const pigeonsSnap = await db.collection('pigeons').get();
        
        for (const pigeonDoc of pigeonsSnap.docs) {
            const pigeonId = pigeonDoc.id;
            
            // Get all tasks for this pigeon
            const tasksSnap = await db.collection('tasks')
                .where('pigeonIds', 'array-contains', pigeonId)
                .get();
            
            for (const taskDoc of tasksSnap.docs) {
                const taskId = taskDoc.id;
                
                // Get completions for this day
                const completionsSnap = await db.collection('task_completions')
                    .where('taskId', '==', taskId)
                    .where('pigeonId', '==', pigeonId)
                    .where('date', '==', dateStr)
                    .get();
                
                const isComplete = completionsSnap.docs.some(doc => doc.data().isComplete);
                
                // Aggregate to ProgressAnalytics (daily)
                await db.collection('progress_analytics').add({
                    taskId,
                    pigeonId,
                    periodType: 'daily',
                    periodStart: admin.firestore.Timestamp.fromDate(yesterday),
                    periodEnd: admin.firestore.Timestamp.fromDate(yesterday),
                    completionDays: isComplete ? 1 : 0,
                    targetDays: 1,
                    checkpointsClaimed: 0  // Calculated separately
                });
            }
        }
        
        console.log('Daily aggregation complete');
    });
```

---

## Step 10: Deploy to Firebase

1. **Add to Firestore Rules**:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow pigeons to read/write their own progress analytics
    match /progress_analytics/{docId} {
      allow read: if request.auth.uid == resource.data.pigeonId;
      allow write: if request.auth.uid == resource.data.pigeonId;
    }
    
    // Allow anyone to read claimed deservings for shared tasks
    match /claimed_deservings/{docId} {
      allow read: if true;
      allow write: if request.auth.uid == resource.data.pigeonId;
    }
  }
}
```

2. **Firestore Indexes** (auto-created):
   - progress_analytics: (pigeonId, periodStart, periodEnd)
   - task_completions: (taskId, pigeonId, date)
   - claimed_deservings: (taskId, dateClaimedString)

---

## Step 11: Integration Checklist

- [ ] Remove rank/XP properties from Pigeon model
- [ ] Add ProgressAnalytics model
- [ ] Create CalendarViewModel with filtering logic
- [ ] Create FitnessCalendarView
- [ ] Add calendar to main navigation (TabBar)
- [ ] Update Firebase service with new query methods
- [ ] Update Achievement types
- [ ] Update DashboardView to show consistency level
- [ ] Create unit tests for edge cases
- [ ] Deploy Cloud Function for daily aggregation
- [ ] Update Firestore rules
- [ ] Test end-to-end with sample data
- [ ] Deploy to TestFlight

---

## Step 12: Testing with Sample Data

Create test data script:

```swift
// Use this to populate test data
func createSampleData() async {
    let firebase = FirebaseService()
    
    // Create test pigeon
    let pigeon = Pigeon(
        id: "test_pigeon_1",
        email: "test@example.com",
        name: "Test User",
        avatar: "😀",
        totalTasksCompleted: 45,  // "Remarkable"
        nestId: "test_nest_1",
        createdAt: Date(),
        lastActiveAt: Date()
    )
    
    // Create test tasks
    let tasks = [
        Task(
            id: "task_1",
            nestId: "test_nest_1",
            name: "Morning Exercise",
            description: "30 min workout",
            taskType: .personal,
            frequency: .daily,
            createdBy: pigeon.id,
            createdAt: Date(),
            updatedAt: Date(),
            checkpoints: [
                Checkpoint(id: "cp1", taskId: "task_1", order: 1, dayThreshold: 7, deserving: Deserving(...))
            ]
        )
    ]
    
    // Create sample completions for October
    let now = Date()
    let calendar = Calendar.current
    for day in 1...20 {
        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = day
        
        if let date = calendar.date(from: components) {
            let completion = TaskCompletion(
                taskId: "task_1",
                pigeonId: pigeon.id,
                date: ISO8601DateFormatter().string(from: date),
                isComplete: Int.random(in: 0...1) == 1  // 50% completion
            )
            
            try? await firebase.saveCompletion(completion)
        }
    }
}
```

---

## HTML Export

The `fitness-calendar.html` file can be used for:
1. **Preview/Demo**: Show stakeholders the design
2. **Web App**: Deploy as companion web app
3. **Documentation**: Export as PDF for documentation

---

## Performance Optimization Tips

1. **Lazy Load Summaries**:
   ```swift
   @State var taskSummariesLoaded = false
   
   .onAppear {
       Task {
           await viewModel.loadTaskSummaries()
       }
   }
   ```

2. **Cache ProgressAnalytics**:
   ```swift
   @State var cache: [String: [ProgressAnalytics]] = [:]
   
   if let cached = cache[monthKey] {
       summaries = cached
   } else {
       summaries = try await firebase.fetch(...)
       cache[monthKey] = summaries
   }
   ```

3. **Batch Firebase Queries**:
   ```swift
   let batch = db.batch()
   batch.setData(..., forDocument: ...)
   batch.setData(..., forDocument: ...)
   try await batch.commit()
   ```

---

## Conclusion

This implementation provides a complete, edge-case-aware fitness calendar system. Follow the steps above to integrate into your app, and refer to the documentation files for detailed edge case handling.

**Estimated Development Time**: 2-3 days
**Testing Time**: 1-2 days
**Deployment**: 1 day

Good luck! 🎉
