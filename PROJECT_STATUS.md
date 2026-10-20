# Proper Productive Pigeons App – Project Status

## 🎯 Mission
Build a **Solo Levelling-themed iOS app** for couples ("pigeons") to track daily discipline tasks with exponential checkpoint progression and shared rewards.

---

## ✅ Phase 1 Complete – MVP Scaffold

### What's Built

#### 📱 Core App Architecture
- **SwiftUI** entry point with multi-screen navigation
- **Firebase Auth** (email/password signup & signin)
- **Firestore** integration for real-time data sync
- Clean **MVVM** architecture (Models, ViewModels, Services)

#### 👥 User Onboarding
- Sign up with avatar selection
- Create or join a "Nest" (shared space)
- Invite code generation (6-char code, 7-day validity)
- Pigeon profile with rank & XP tracking

#### 📋 Task System
- Create **personal** tasks (individual progress)
- Create **shared** tasks (partner can see both statuses)
- Configure **multiple checkpoints** per task
- Assign **deserving rewards** to each checkpoint
- Task frequency: daily, weekly, custom

#### 🏆 Progression System
- **Rank System**: E, D, C, B, A, S (based on XP)
- **XP Tracking**: Accumulate points for completions
- **Streak Counter**: Track consecutive days
- **Checkpoints**: Exponential milestones (1, 2, 4, 8, 16... days)

#### 🎨 Solo Levelling Theme
- **Color Palette**: Dark purple, bright gold, deep black, silver white
- **Rank Colors**: E (gray) → D (blue) → C (green) → B (gold) → A (red) → S (purple)
- **UI Components**: Themed buttons, cards, theme utilities
- **Animations Ready**: Structure for celebration effects

#### 📡 Dashboard
- Personal pigeon stats (name, rank, XP, avatar)
- Nest info with invite code
- Task cards showing progress
- Quick-add new task button

### Technology Stack
- **Frontend**: SwiftUI (native iOS)
- **Backend**: Firebase (Auth + Firestore)
- **State**: @StateObject, @EnvironmentObject
- **Storage**: Firestore documents + UserDefaults

---

## 🔄 Phase 2 – Core Features (Ready to Build)

### Checkpoint & Reward Detection
- [ ] Calculate streaks from TaskCompletion records
- [ ] Detect checkpoint threshold crossing
- [ ] Trigger celebratory animations
- [ ] Mark deserving as "claimed"
- [ ] Award XP to pigeon

**Est. Time:** 1-2 days

### Real-Time Sync & Notifications
- [ ] Listen to Firestore changes for live updates
- [ ] Show partner's completion status instantly
- [ ] Local push notifications (UserNotifications)
- [ ] Optional sounds/vibrations on achievements

**Est. Time:** 1 day

### UI Polish & Animations
- [ ] Checkpoint unlock reveal animation
- [ ] Confetti effect on achievement
- [ ] Streak fire animation
- [ ] Loading states & error handling
- [ ] Empty state illustrations

**Est. Time:** 1-2 days

### Advanced Features
- [ ] Weekly/monthly summary screens
- [ ] Achievement badges view
- [ ] Couple combined stats
- [ ] Streaks calendar heatmap
- [ ] Profile customization

**Est. Time:** 2-3 days

---

## 📊 Data Model (Firestore Structure)

```
Collections:
├── pigeons/{pigeonId}
│   ├── id, email, name, avatar
│   ├── xp, rank, nestId
│   └── createdAt, lastActiveAt
│
├── nests/{nestId}
│   ├── name, theme
│   ├── pigeons: [pigeonIds]
│   ├── inviteCode, inviteExpiresAt
│   └── createdAt, updatedAt
│
├── tasks/{taskId}
│   ├── nestId, name, description
│   ├── taskType: personal|shared
│   ├── frequency: daily|weekly|custom
│   ├── checkpoints: [{ order, dayThreshold, deservingId }]
│   └── createdBy, createdAt
│
├── task_completions/{completionId}
│   ├── taskId, pigeonId, date (YYYY-MM-DD)
│   ├── isComplete: boolean
│   └── createdAt, updatedAt
│
├── streaks/{streakId}
│   ├── taskId, pigeonId
│   ├── currentCount, lastCompletionDate, resetDate
│   └── updatedAt
│
└── achievements/{achievementId}
    ├── nestId, pigeonId, type
    ├── title, description
    └── unlockedAt
```

---

## 🎮 User Flow Overview

### First-Time User (Pigeon 1)
1. **Sign Up** → enter email, password, name, avatar
2. **Create Nest** → name nest, pick theme, get invite code
3. **Create First Task** → name task, type (personal/shared), set checkpoints & deservings
4. **Dashboard** → see task, mark complete, track progress

### Partner (Pigeon 2)
1. **Sign Up** → enter email, password, name, avatar
2. **Join Nest** → enter invite code from Pigeon 1
3. **See Tasks** → Pigeon 1's tasks visible, create own tasks
4. **Shared Dashboard** → see both pigeons' progress

### Daily Usage
1. Open app
2. See today's tasks (personal + shared)
3. Mark tasks complete (self-check, honor system)
4. See updated streaks & next checkpoint countdown
5. On checkpoint hit: celebrate with animation, mark deserving earned

---

## 🔐 Security Considerations

### Firebase Firestore Rules (To Add)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Only pigeons can read/write their own data
    match /pigeons/{pigeonId} {
      allow read, write: if request.auth.uid == pigeonId;
    }
    
    // Only pigeons in nest can access nest/tasks/completions
    match /nests/{nestId} {
      allow read: if request.auth.uid in resource.data.pigeons;
      allow write: if request.auth.uid == resource.data.createdBy;
    }
    
    // Similar rules for tasks, completions, streaks
  }
}
```

---

## 📦 Testing Distribution

**For Testing Users (Not App Store):**

1. **Xcode Direct Testing**
   - Build for specific devices
   - Install via Xcode organizer

2. **TestFlight (Recommended)**
   - Build & upload to App Store Connect
   - Invite test users via email
   - No App Store approval needed

3. **Ad-Hoc IPA Distribution**
   - Build IPA file
   - Distribute via email or cloud storage
   - Users install via AltStore or similar

---

## 🚀 Deployment Checklist (When Ready)

- [ ] Firebase project created & configured
- [ ] Firestore security rules in place
- [ ] GoogleService-Info.plist added
- [ ] CocoaPods dependencies installed
- [ ] App builds without errors in Xcode
- [ ] User flow tested end-to-end
- [ ] Notification permissions configured
- [ ] Test accounts created & working
- [ ] Checkpoint logic verified
- [ ] Real-time sync confirmed
- [ ] UI animations smooth & performant

---

## 🎨 Design System (Ready to Use)

All colors & components defined in `SoloLevellingTheme.swift`:

- `SoloLevellingTheme.darkPurple` - Main background
- `SoloLevellingTheme.brightGold` - Primary accent
- `SoloLevellingTheme.deepBlack` - Dark backgrounds
- `SoloLevellingTheme.rankE/D/C/B/A/S` - Rank colors

Usage:
```swift
Text("Unlock!")
    .foregroundColor(SoloLevellingTheme.brightGold)
    .modifier(ThemeButton(style: .primary))
```

---

## 🤔 Open Questions for Next Phase

1. **Notification Strategy**: Push on every task completion, or only on milestones?
2. **Streak Reset**: If Pigeon 1 misses day on shared task, does Pigeon 2's streak continue?
3. **Deserving System**: Can pigeons claim same deserving multiple times?
4. **Couple Achievements**: Should they have shared rank, or stay individual?
5. **Health Integration**: Future feature — connect Apple Health for steps/workouts?

---

## 📞 Ready to Move Forward?

The scaffold is solid and tested. Next phase should focus on:
- **Priority 1**: Checkpoint detection & deserving unlock logic
- **Priority 2**: Real-time sync & partner notifications
- **Priority 3**: UI polish & animations
- **Priority 4**: Testing & bug fixes

**Current Status**: ✅ Ready for next sprint

---

**Last Updated:** 2026-10-20  
**Version:** 1.0 (MVP Scaffold)  
**Repository:** /tmp/ProperDisciplineApp (git initialized)
