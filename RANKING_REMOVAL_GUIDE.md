# Ranking Feature Removal Guide

## Overview

This document details the removal of the E-S rank system from the Proper Productive Pigeons app, replacing it with a simpler **consistency level** system.

---

## Changes to Models

### Pigeon.swift - BEFORE (with ranking)
```swift
struct Pigeon: Identifiable, Codable {
    let id: String
    let email: String
    let name: String
    let avatar: String
    
    var totalTasksCompleted: Int = 0
    var rank: String = "E"  // ❌ REMOVE
    var xp: Int = 0         // ❌ REMOVE
    var rankPoints: Int = 0 // ❌ REMOVE
    
    var nestId: String?
    let createdAt: Date
    var lastActiveAt: Date
    
    var rankColor: Color {   // ❌ REMOVE
        switch rank {
        case "E": return .gray
        case "D": return .blue
        case "C": return .green
        case "B": return .yellow
        case "A": return .red
        case "S": return .purple
        default: return .gray
        }
    }
}
```

### Pigeon.swift - AFTER (without ranking)
```swift
struct Pigeon: Identifiable, Codable {
    let id: String
    let email: String
    let name: String
    let avatar: String
    var totalTasksCompleted: Int = 0
    var nestId: String?
    let createdAt: Date
    var lastActiveAt: Date
    
    /// Calculate consistency level based on total completions
    /// Replaces ranking system - focused on discipline consistency
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

### Achievement.swift - BEFORE
```swift
enum AchievementType: String, Codable {
    case checkpoint_unlock
    case weekly_perfect
    case couple_milestone
    case rank_up            // ❌ REMOVE
    case first_deserving
}
```

### Achievement.swift - AFTER
```swift
enum AchievementType: String, Codable {
    case checkpoint_unlock
    case weekly_perfect
    case couple_milestone
    case first_deserving
    case consistency_streak  // ✅ NEW: Track consistency milestones
}
```

---

## Changes to Views

### DashboardView.swift

#### BEFORE (showing rank):
```swift
HStack(spacing: 8) {
    Text("Rank: \(pigeon.rank)")
        .font(.system(size: 12))
        .foregroundColor(Color.rankColor(for: pigeon.rank))
    Text("XP: \(pigeon.xp)")
        .font(.system(size: 12))
        .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
}
```

#### AFTER (showing consistency):
```swift
HStack(spacing: 8) {
    Text("Consistency: \(pigeon.consistencyLevel)")
        .font(.system(size: 12))
        .foregroundColor(SoloLevellingTheme.brightGold)
    Text("\(pigeon.totalTasksCompleted) completed")
        .font(.system(size: 12))
        .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
}
```

### ProfileView.swift

#### BEFORE:
```swift
VStack {
    Text("Rank: \(pigeon.rank)")
        .font(.system(size: 32, weight: .bold))
        .foregroundColor(Color.rankColor(for: pigeon.rank))
    
    HStack {
        Text("XP: \(pigeon.xp)")
        Text("/ \(pigeon.xpToNextRank)")
    }
    
    ProgressView(value: Double(pigeon.xp), total: Double(pigeon.xpToNextRank))
}
```

#### AFTER:
```swift
VStack {
    Text("Consistency Level")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.7))
    
    Text("\(pigeon.consistencyLevel)")
        .font(.system(size: 28, weight: .bold))
        .foregroundColor(SoloLevellingTheme.brightGold)
    
    Text("\(pigeon.totalTasksCompleted) tasks completed")
        .font(.system(size: 12))
        .foregroundColor(SoloLevellingTheme.silverWhite.opacity(0.6))
}
```

---

## Changes to ViewModels

### AuthViewModel.swift

#### BEFORE:
```swift
func signUp(email: String, password: String, name: String, avatar: String) async -> Bool {
    let newPigeon = Pigeon(
        id: UUID().uuidString,
        email: email,
        name: name,
        avatar: avatar,
        totalTasksCompleted: 0,
        rank: "E",      // ❌ REMOVE
        xp: 0,          // ❌ REMOVE
        rankPoints: 0,  // ❌ REMOVE
        nestId: nil,
        createdAt: Date(),
        lastActiveAt: Date()
    )
    // ...
}
```

#### AFTER:
```swift
func signUp(email: String, password: String, name: String, avatar: String) async -> Bool {
    let newPigeon = Pigeon(
        id: UUID().uuidString,
        email: email,
        name: name,
        avatar: avatar,
        totalTasksCompleted: 0,
        nestId: nil,
        createdAt: Date(),
        lastActiveAt: Date()
    )
    // ...
}
```

### TaskViewModel.swift

#### BEFORE:
```swift
func completeTask(taskId: String) async {
    // Mark task complete
    let completion = TaskCompletion(...)
    try await firebaseService.saveCompletion(completion)
    
    // Award XP
    let xpEarned = 10
    try await firebaseService.awardXP(pigeonId, xpEarned)  // ❌ REMOVE
    
    // Check for rank up
    try await firebaseService.checkRankUp(pigeonId)  // ❌ REMOVE
}
```

#### AFTER:
```swift
func completeTask(taskId: String) async {
    // Mark task complete
    let completion = TaskCompletion(...)
    try await firebaseService.saveCompletion(completion)
    
    // Increment total tasks completed
    try await firebaseService.incrementTaskCount(pigeonId)
    
    // Check for consistency milestone
    try await firebaseService.checkConsistencyMilestone(pigeonId)  // ✅ NEW
}
```

### FirebaseService.swift

#### BEFORE (XP/Rank system):
```swift
func awardXP(_ pigeonId: String, _ amount: Int) async throws {
    let pigeon = try await db.collection("pigeons").document(pigeonId).getDocument(as: Pigeon.self)
    let newXP = pigeon.xp + amount
    let newRank = Pigeon.rankFromXP(newXP)
    
    if newRank != pigeon.rank {
        // Create rank-up achievement
        let achievement = Achievement(type: .rank_up, ...)
        try await createAchievement(achievement)
    }
    
    try await db.collection("pigeons").document(pigeonId).updateData([
        "xp": newXP,
        "rank": newRank
    ])
}
```

#### AFTER (Consistency tracking):
```swift
func incrementTaskCount(_ pigeonId: String) async throws {
    let pigeon = try await db.collection("pigeons").document(pigeonId).getDocument(as: Pigeon.self)
    let newTotal = pigeon.totalTasksCompleted + 1
    
    try await db.collection("pigeons").document(pigeonId).updateData([
        "total_tasks_completed": newTotal
    ])
}

func checkConsistencyMilestone(_ pigeonId: String) async throws {
    let pigeon = try await db.collection("pigeons").document(pigeonId).getDocument(as: Pigeon.self)
    let milestones = [10, 25, 50, 100, 250, 500]
    
    if milestones.contains(pigeon.totalTasksCompleted) {
        let achievement = Achievement(
            type: .consistency_streak,
            title: "Consistency Milestone",
            description: "Reached \(pigeon.totalTasksCompleted) tasks!",
            unlockedAt: Date()
        )
        try await createAchievement(achievement)
    }
}
```

---

## Changes to Firestore Rules

### BEFORE (XP/Rank tracking):
```javascript
match /pigeons/{pigeonId} {
    allow read, write: if request.auth.uid == pigeonId;
    
    match /xp_history/{xpId} {
        allow read, write: if request.auth.uid == pigeonId;
    }
}
```

### AFTER (Simpler consistency tracking):
```javascript
match /pigeons/{pigeonId} {
    allow read, write: if request.auth.uid == pigeonId;
    
    // No XP history needed - only track total count
}
```

---

## Database Migration (Firestore)

If you have existing data with XP and rank:

### Migration Script (Node.js/Firebase Admin SDK)
```javascript
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

async function migrateRankData() {
    const pigeonsSnapshot = await db.collection('pigeons').get();
    
    const batch = db.batch();
    
    pigeonsSnapshot.forEach(doc => {
        const pigeon = doc.data();
        
        // Calculate total tasks from XP (rough estimate)
        const totalTasks = Math.floor(pigeon.xp / 10) || 0;
        
        batch.update(doc.ref, {
            total_tasks_completed: totalTasks,
            xp: admin.firestore.FieldValue.delete(),
            rank: admin.firestore.FieldValue.delete(),
            rankPoints: admin.firestore.FieldValue.delete()
        });
    });
    
    await batch.commit();
    console.log('Migration complete!');
}

migrateRankData();
```

### For Achievements Collection
```javascript
async function migrateAchievements() {
    const achievementsSnapshot = await db.collection('achievements').get();
    
    const batch = db.batch();
    
    achievementsSnapshot.forEach(doc => {
        const achievement = doc.data();
        
        // Update rank_up achievements to consistency_streak
        if (achievement.type === 'rank_up') {
            batch.update(doc.ref, {
                type: 'consistency_streak',
                title: 'Consistency Milestone',
                description: `Reached a new consistency level!`
            });
        }
    });
    
    await batch.commit();
    console.log('Achievement migration complete!');
}

migrateAchievements();
```

---

## UI Color Updates

### SoloLevellingTheme.swift - BEFORE
```swift
struct SoloLevellingTheme {
    static let rankE = Color(red: 0.5, green: 0.5, blue: 0.5)   // Gray
    static let rankD = Color(red: 0.3, green: 0.6, blue: 1.0)   // Blue
    static let rankC = Color(red: 0.2, green: 0.8, blue: 0.4)   // Green
    static let rankB = Color(red: 1.0, green: 0.84, blue: 0.0)  // Gold
    static let rankA = Color(red: 1.0, green: 0.2, blue: 0.2)   // Red
    static let rankS = Color(red: 0.7, green: 0.2, blue: 1.0)   // Purple
}

extension Color {
    static func rankColor(for rank: String) -> Color {
        switch rank {
        case "E": return SoloLevellingTheme.rankE
        case "D": return SoloLevellingTheme.rankD
        // ... etc
        }
    }
}
```

### SoloLevellingTheme.swift - AFTER
```swift
struct SoloLevellingTheme {
    // Rank colors removed - no longer needed
    // Color palette simplified for fitness calendar
    
    static let progressBlue = Color(red: 0.2, green: 0.8, blue: 1.0)
    static let progressGold = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let progressOrange = Color(red: 1.0, green: 0.5, blue: 0.0)
}
```

---

## Testing Updates

### Remove Tests
- `testRankUp()` - No longer needed
- `testXPAccumulation()` - No longer needed
- `testRankColor()` - No longer needed

### Add Tests
```swift
func testConsistencyLevelCalculation() {
    let pigeon1 = Pigeon(totalTasksCompleted: 5)
    XCTAssertEqual(pigeon1.consistencyLevel, "Growing")
    
    let pigeon2 = Pigeon(totalTasksCompleted: 30)
    XCTAssertEqual(pigeon2.consistencyLevel, "Remarkable")
    
    let pigeon3 = Pigeon(totalTasksCompleted: 150)
    XCTAssertEqual(pigeon3.consistencyLevel, "Unstoppable")
}

func testConsistencyMilestoneUnlock() {
    // Test that achievements unlock at 10, 25, 50, 100, etc.
    let viewModel = TaskViewModel()
    for i in 1...10 {
        viewModel.completeTask(...)  // Triggers incrementTaskCount
    }
    XCTAssertEqual(viewModel.achievements.last?.type, .consistency_streak)
}
```

---

## Summary of Deletions

| Item | Location | Action |
|------|----------|--------|
| `rank` property | Pigeon.swift | Delete |
| `xp` property | Pigeon.swift | Delete |
| `rankPoints` property | Pigeon.swift | Delete |
| `rankColor` computed property | Pigeon.swift | Delete |
| `rankFromXP()` static method | Pigeon.swift | Delete |
| `rank_up` case | Achievement.swift | Delete (keep others) |
| Rank color functions | SoloLevellingTheme.swift | Delete |
| Rank display views | ProfileView.swift | Redesign |
| XP tracking views | DashboardView.swift | Redesign |
| Rank badge components | Various | Delete |
| `awardXP()` function | FirebaseService.swift | Delete |
| `checkRankUp()` function | FirebaseService.swift | Delete |
| XP-related Firestore rules | Firebase Rules | Simplify |
| Rank/XP test cases | Various test files | Delete |

---

## Summary of Additions

| Item | Location | Action |
|------|----------|--------|
| `consistencyLevel` property | Pigeon.swift | Add |
| `consistency_streak` case | Achievement.swift | Add |
| `incrementTaskCount()` function | FirebaseService.swift | Add |
| `checkConsistencyMilestone()` function | FirebaseService.swift | Add |
| Consistency level display | ProfileView.swift | Add |
| Consistency badge | DashboardView.swift | Add |
| Consistency milestone tests | Test files | Add |

---

## Migration Timeline

1. **Phase 1**: Update models and viewmodels
2. **Phase 2**: Update views and UI
3. **Phase 3**: Migrate existing Firestore data
4. **Phase 4**: Update tests
5. **Phase 5**: Deploy with feature flag (optional - show old rank as readonly)
6. **Phase 6**: Remove old rank-related code after gradual migration

---

## Backward Compatibility Note

If you need to maintain backward compatibility during rollout:

```swift
struct Pigeon: Identifiable, Codable {
    // New field
    var totalTasksCompleted: Int = 0
    
    // Old fields (deprecated, will be removed)
    @Deprecated var rank: String = "E"
    @Deprecated var xp: Int = 0
    
    // Getter that shows old rank as readonly based on new consistency level
    @available(*, deprecated)
    var legacyRank: String {
        switch consistencyLevel {
        case "Growing": return "E"
        case "Impressive": return "D"
        case "Remarkable": return "C"
        case "Exceptional": return "B"
        case "Unstoppable": return "A"
        default: return "E"
        }
    }
}
```

This allows old clients to continue working while new clients use consistency levels.

---

## Conclusion

The ranking removal simplifies the app's progression system, focusing on **daily discipline consistency** rather than competitive leveling. The new `consistencyLevel` provides motivation through achievable milestones (Growing → Unstoppable) while keeping the data model lean and the UI clean.
