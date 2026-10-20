# Fitness Calendar View - Architecture & Edge Cases

## Overview

This document outlines the new Apple Fitness-style calendar view with progress circles, filtering capabilities, and comprehensive edge case handling for the Proper Productive Pigeons app.

---

## Key Features

### 1. Progress Circle Display (Apple Fitness Style)
- **Visual Design**: Concentric progress rings showing completion status
- **Personal Goals**: Blue/cyan ring (inner)
- **Shared Goals**: Gold/orange ring (outer)
- **Perfect Day Indicator**: Full rings + today border
- **Checkpoint Marker**: Gold star (⭐) appears when deserving is claimed

### 2. Filtering System
Three filter modes with real-time circle recalculation:

#### Personal Only (Default)
- Shows only personal task progress
- Shared ring is hidden
- Circle calculation: `personal_progress / total_personal_tasks`

#### Shared Only
- Shows only shared task progress
- Personal ring is hidden
- Circle calculation: `shared_progress / total_shared_tasks`

#### Both (All Goals)
- Shows both personal and shared rings
- Combined tracking visible
- Separate progress rings stacked concentrically

```swift
// CalendarViewModel filter logic
switch filterMode {
case .personal:
    filteredProgress = personalProgress
case .shared:
    filteredProgress = sharedProgress
case .both:
    filteredProgress = (personalProgress + sharedProgress) / 2
}
```

### 3. Time Period Switching
View progress across different time windows:
- **Weekly**: 7-day rolling window or calendar week
- **Monthly**: Current calendar month
- **Quarterly**: 3-month period
- **Yearly**: Full calendar year

Each period recalculates task summaries and progress percentages.

---

## Data Flow & Storage

### View Layer (Temporary)
- Calendar resets when period changes
- Current display shows only selected time range
- No persistence at this layer

### Data Layer (Permanent)
```
ProgressAnalytics Collection (Firestore):
├── id: UUID
├── taskId, pigeonId
├── periodType: daily|weekly|monthly|quarterly|yearly
├── periodStart, periodEnd: Dates
├── completionDays: Int
├── targetDays: Int
├── checkpointsClaimed: Int
└── [stored in Firestore permanently]
```

**Key Insight**: Raw daily TaskCompletion records are aggregated into ProgressAnalytics records at period boundaries.

### Yearly Progress Example
```
User opens app on Oct 20, 2026:
- Views Oct 2026 calendar (current month, incomplete)
- Switches to "Yearly" view
- Shows aggregated data from Jan-Oct 2026
- Quarterly view shows Q1, Q2, Q3, Q4 data
- All backed by ProgressAnalytics records calculated at period end
```

---

## Edge Cases & Handling

### 1. **Data Gaps (Missing Sync)**
**Scenario**: User goes offline for 3 days, tasks not synced
- **Detection**: `CalendarDayProgress.hasNoData` flag
- **UI Signal**: Gray circle + data gap warning
- **Handling**:
  ```swift
  private func detectDataGaps() {
      let daysWithoutData = calendarDays.filter { $0.hasNoData }
      hasDataGaps = !daysWithoutData.isEmpty
  }
  ```
- **User Action**: Retrigger sync when online

### 2. **Incomplete Current Month**
**Scenario**: Viewing current month before month ends
- **Detection**: Last day with data < today
- **UI Signal**: "Current month in progress" notice
- **Handling**:
  ```swift
  if isCurrentMonth {
      let lastDayWithData = calendarDays.last(where: { !$0.hasNoData })?.date
      incompleteMonth = lastDayWithData == nil || lastDayWithData! < today
  }
  ```
- **Behavior**: Summary shows "In Progress" status, percentage updates daily

### 3. **No Tasks Created Yet**
**Scenario**: First-time user, no tasks defined
- **Detection**: `taskSummaries.isEmpty`
- **UI Signal**: Empty state with illustration
- **Action**: Prompt to create first task
  ```html
  <div class="empty-state">
      <div class="empty-state-icon">📋</div>
      <p>No tasks yet. Create your first goal to start tracking.</p>
  </div>
  ```

### 4. **Mixed Personal/Shared Progress**
**Scenario**: Partner completed shared task but user didn't
- **Storage**: Separate completion records per pigeon
- **Calculation**: 
  ```
  Day Progress = {
      personalProgress: 0.75,
      sharedProgress: 0.25
  }
  ```
- **Display**: Both rings shown, user can see partner's progress
- **Filter**: 
  - "Personal" shows only user's 0.75
  - "Shared" shows only shared's 0.25
  - "Both" shows both rings concentrically

### 5. **Checkpoint Claimed on Same Day**
**Scenario**: User hits checkpoint for "Exercise" task on Oct 15
- **Data**:
  ```swift
  CalendarDayProgress(date: Oct 15) {
      personalProgress: 1.0
      personalCheckpointsClaimed: 1  // Claim count
  }
  ```
- **UI**: Star (⭐) appears on Oct 15 circle
- **Detail Modal**: Shows "1 deserving claimed" with reward details
- **Celebration Effect**: 
  ```
  🎉 Deserving Unlocked!
  Morning Exercise
  Reward: 4-hour gaming session
  ```

### 6. **Multiple Checkpoints in One Day**
**Scenario**: User hits checkpoint for Exercise AND hits checkpoint for Study
- **Handling**:
  ```swift
  dayProgress.personalCheckpointsClaimed = 2  // Two different tasks
  ```
- **UI**: Star badge remains (indicator only, details in modal)
- **Modal**: Lists both claimed deservings

### 7. **Leap Year / Month Length Edge Cases**
**Scenario**: Feb in leap year has 29 days, viewing March with 31 days
- **Handling**: `Calendar.range(of: .day, in: .month)` handles automatically
- **Grid**: Adjusts columns/rows dynamically
  ```swift
  private func getWeekCount() -> Int {
      let calendar = Calendar.current
      let range = calendar.range(of: .day, in: .month, for: viewModel.selectedMonth)!
      let numDays = range.count
      return (numDays + 6) / 7  // Always rounds up to week count
  }
  ```

### 8. **Filter Change Mid-View**
**Scenario**: Viewing "Both" goals, switches to "Personal"
- **Recalculation**:
  ```swift
  func applyFilter() {
      switch filterMode {
      case .personal:
          filterPersonalOnly()  // Set shared rings to 0
      case .shared:
          filterSharedOnly()    // Set personal rings to 0
      case .both:
          keepBoth()           // No filtering
      }
  }
  ```
- **Animation**: Rings smoothly adjust
- **Summaries**: Update to show only filtered tasks

### 9. **Period Switch Boundary**
**Scenario**: Viewing Oct, user is looking at Nov (future month)
- **Prevention**:
  ```swift
  func canGoToNextMonth() -> Bool {
      let calendar = Calendar.current
      let today = Date()
      if let nextMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
          return nextMonth <= today  // Can't view future months
      }
      return false
  }
  ```
- **UI**: Next button disabled if would show future

### 10. **Partner Offline During Shared Task**
**Scenario**: Shared task completed by one pigeon, other offline
- **Your Progress**: Shows your 100% (completed) on circle
- **Shared Ring**: Shows partner's last-synced progress (e.g., 50%)
- **Warning**: "Pending sync" indicator if timestamp is old
- **Auto-update**: Refreshes when partner comes online

### 11. **Year Boundary (Dec → Jan)**
**Scenario**: Switching from December to January (next year)
- **Handling**: `Calendar.dateComponents([.year, .month])`  determines year
- **Yearly View**: Shows appropriate year when selected
- **Data**: ProgressAnalytics records labeled with year

### 12. **Zero Target Days**
**Scenario**: Task removed mid-period, target becomes 0
- **Edge Case Protection**:
  ```swift
  var progressPercentage: Double {
      guard targetDays > 0 else { return 0 }  // Prevent division by zero
      return Double(completionDays) / Double(targetDays) * 100
  }
  ```
- **UI**: Shows gray circle, "0%" text
- **Summary**: Skipped or marked as "cancelled"

### 13. **Timezone Mismatch**
**Scenario**: User travels, system timezone changes
- **Solution**: Store dates as ISO8601 strings
  ```swift
  let dateStr = ISO8601DateFormatter().string(from: date)
  // Always: "2026-10-15T00:00:00Z"
  ```
- **Handling**: Queries use UTC, display adjusted to local timezone
- **Mitigation**: Data stored server-side in UTC

### 14. **Concurrent Checkpoint Claims**
**Scenario**: Both pigeons claim same checkpoint on same day
- **Storage**: Separate ClaimedDeserving records per pigeon
- **Display**: Count both claims
  ```swift
  struct ClaimedDeserving {
      let pigeonId: String
      let dateClaimedString: String
      let taskType: Task.TaskType
  }
  ```
- **UI**: Shows "2 deservings claimed" with both names

### 15. **Rotation/Screen Size Change**
**Scenario**: iPad rotated portrait → landscape
- **CSS/SwiftUI**: 
  - Calendar grid uses `@media` / `GeometryReader`
  - Responsive: 7 columns always, rows adjust
  - Modal repositions from bottom-sheet → side-panel

---

## Circle Calculation Formula

### Progress Ring Stroke
```
Each circle is 360° = 339.292 SVG units (for circumference ≈ 2πr)
Progress fills arc based on percentage:

stroke-dasharray = progress_percentage * circumference
stroke-dashoffset = 0 (creates arc from top)

Example: 75% progress
stroke-dasharray = 0.75 * 339.292 = 254.469
Result: 3/4 ring filled
```

### Multi-Ring Display
```
Personal Ring (outer):
- cx="60" cy="60" r="54"
- stroke-width="3"

Shared Ring (inner):
- cx="60" cy="60" r="48"
- stroke-width="2.5"
- Offset by padding="6"

Result: Concentric rings that don't overlap
```

---

## HTML vs iOS Equivalence

### Responsive Design
| Feature | iOS | HTML |
|---------|-----|------|
| Bottom Sheet Modal | `.sheet()` | `position: fixed; align-items: flex-end;` |
| Filter Buttons | `SegmentedPicker` | Flex row with active state |
| Calendar Grid | `LazyVGrid` 7 cols | CSS `grid-template-columns: repeat(7, 1fr)` |
| Progress Ring | `Circle().trim()` | SVG `<circle>` with `stroke-dasharray` |
| Animations | `.animation()` | CSS `@keyframes` + `transition` |
| Colors | `LinearGradient` | CSS `linear-gradient()` |

### Mobile-First Approach
Both views are optimized for mobile-first design:
- Thumb-friendly tap targets (min 44x44 pts)
- Bottom-aligned modals
- Horizontal scrolling summaries on small screens
- Full-screen calendar grid

---

## Implementation Checklist

### Data Models
- [x] `ProgressAnalytics` - Historical data storage
- [x] `CalendarDayProgress` - Daily progress with filtering
- [x] `TaskPeriodSummary` - Period-level aggregates
- [x] `ClaimedDeserving` - Deserving claim tracking

### ViewModels
- [x] `CalendarViewModel` - Calendar state + filtering logic
- [x] Data loading from Firebase
- [x] Edge case detection
- [x] Time period switching

### Views
- [x] `FitnessCalendarView` - Main calendar UI
- [x] Progress circles with rings
- [x] Filter controls
- [x] Day detail modal
- [x] Task summaries
- [x] Warning banners

### HTML
- [x] Interactive calendar with SVG circles
- [x] Filter & period selectors
- [x] Day detail modal
- [x] Task summaries with progress bars
- [x] Celebration case for deserving unlock
- [x] Responsive design

### Firebase Integration Needed
- [ ] `fetchTaskCompletions(date, taskType)`
- [ ] `fetchTaskSummaries(month, period, filterMode)`
- [ ] `fetchProgressAnalytics(period)` - Retrieve historical data
- [ ] Aggregation job (daily → weekly → monthly → quarterly → yearly)

---

## Future Enhancements

1. **Streak Visualization**: Continuous days indicator
2. **Heatmap Mode**: Intensity-based coloring (GitHub style)
3. **Partner Comparison**: Side-by-side progress circles
4. **Notifications**: "Checkpoint approaching" alerts
5. **Export**: Download progress data as CSV/PDF
6. **Dark Mode**: Already built-in, toggle in settings
7. **Accessibility**: VoiceOver labels, high contrast mode

---

## Ranking Feature Removal

**Previous System Removed**:
- Rank system (E-S) based on XP
- Rank-up achievements
- Rank color indicators
- XP accumulation display

**Reason**: Focus on consistent discipline tracking vs. competitive leveling

**Preserved**: Consistency level for motivation ("Growing" → "Unstoppable")

---

## Testing Strategy

### Unit Tests
```swift
// Test progress calculation with filters
func testPersonalFilterCalculation() {
    let day = CalendarDayProgress(personal: 0.75, shared: 0.5)
    viewModel.filterMode = .personal
    viewModel.applyFilter()
    XCTAssertEqual(day.personalProgress, 0.75)
    XCTAssertEqual(day.sharedProgress, 0)  // Filtered out
}

// Test edge case: division by zero
func testZeroTargetDays() {
    let summary = TaskPeriodSummary(completionDays: 5, targetDays: 0)
    XCTAssertEqual(summary.progressPercentage, 0)
}

// Test leap year handling
func testFebruaryLeapYear() {
    let feb2024 = Date(timeIntervalSince1970: 1704067200)  // Feb 2024
    let range = calendar.range(of: .day, in: .month, for: feb2024)!
    XCTAssertEqual(range.count, 29)  // Leap year
}
```

### Integration Tests
```swift
// Test complete flow
func testCalendarWithMixedProgress() {
    // Setup: 2 personal tasks (75%, 50%), 1 shared (90%)
    let days = viewModel.generateCalendarDays()
    
    // Personal filter
    viewModel.filterMode = .personal
    viewModel.applyFilter()
    let personalOnly = days[0]
    XCTAssertEqual(personalOnly.personalProgress, 0.625)  // (0.75 + 0.5) / 2
    XCTAssertEqual(personalOnly.sharedProgress, 0)
    
    // Both filter
    viewModel.filterMode = .both
    viewModel.applyFilter()
    let both = days[0]
    XCTAssertEqual(both.combinedProgress, 0.54)  // (0.625 + 0.9) / 2
}
```

---

## Performance Considerations

### Calendar Generation
- Pre-generate days on month change (not real-time)
- Lazy load task summaries
- Cache ProgressAnalytics queries

### Large Datasets
- Pagination for years with 365+ days
- Infinite scroll for historical data
- Backend aggregation (don't sum 365 days client-side)

### Animations
- Use `CADisplayLink` for smooth 60fps circles
- Throttle filter changes (debounce)
- Batch Firebase queries

---

## Conclusion

This calendar view provides a comprehensive, edge-case-aware system for tracking personal and shared discipline goals across multiple time periods. The design mirrors Apple Fitness+ for familiarity while maintaining Solo Levelling theming.
