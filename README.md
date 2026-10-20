# Proper Productive Pigeons App – iOS (Solo Levelling Theme)

A collaborative habit-tracking app for couples ("pigeons") with exponential checkpoint progression, personal and shared goals, and Solo Levelling theming.

## Project Structure

```
ProperDisciplineApp/
├── ProperDisciplineApp/
│   ├── App/
│   │   ├── ProperDisciplineAppApp.swift          # Entry point
│   │   └── AppDelegate.swift
│   │
│   ├── Views/
│   │   ├── AuthenticationView.swift              # Login/Sign up
│   │   ├── OnboardingView.swift                  # Nest creation & first task
│   │   ├── DashboardView.swift                   # Main home screen
│   │   ├── TaskListView.swift                    # Personal & shared tasks
│   │   ├── TaskDetailView.swift                  # Task progress & history
│   │   ├── CheckpointRewardView.swift            # Deserving unlock celebration
│   │   ├── ProfileView.swift                     # Pigeon profile & settings
│   │   └── SettingsView.swift                    # Nest settings, theme, etc.
│   │
│   ├── ViewModels/
│   │   ├── AuthViewModel.swift
│   │   ├── NestViewModel.swift                   # Nest/partner management
│   │   ├── TaskViewModel.swift                   # Task CRUD & completion
│   │   ├── DashboardViewModel.swift              # Dashboard state
│   │   └── RewardViewModel.swift                 # Checkpoint & deserving logic
│   │
│   ├── Models/
│   │   ├── Pigeon.swift                          # User model
│   │   ├── Nest.swift                            # Shared space
│   │   ├── Task.swift                            # Task definition
│   │   ├── Checkpoint.swift                      # Milestone config
│   │   ├── Deserving.swift                       # Reward/permission
│   │   ├── TaskCompletion.swift                  # Daily check-in record
│   │   ├── Streak.swift                          # Streak tracking
│   │   └── Achievement.swift                     # Badges & unlocks
│   │
│   ├── Services/
│   │   ├── FirebaseService.swift                 # Firebase CRUD & auth
│   │   ├── SyncService.swift                     # Real-time sync
│   │   ├── NotificationService.swift             # Local & push notifications
│   │   ├── StorageService.swift                  # Local UserDefaults/Keychain
│   │   └── AnalyticsService.swift                # Event tracking (optional)
│   │
│   ├── Utils/
│   │   ├── Colors.swift                          # Solo Levelling color palette
│   │   ├── SoloLevellingTheme.swift              # Design system
│   │   ├── Animations.swift                      # Reusable animations
│   │   ├── Constants.swift                       # App constants
│   │   └── Extensions.swift                      # Swift extensions
│   │
│   └── Assets/
│       ├── Colors.xcassets
│       ├── Fonts/                                # Solo Levelling fonts (if custom)
│       └── Images/                               # Icons, badges, animations
│
├── ProperDisciplineAppTests/
│   ├── ViewModelTests.swift
│   ├── ServiceTests.swift
│   └── ModelTests.swift
│
├── .gitignore
├── Package.swift                                 # Dependencies (if using SPM)
└── README.md                                     # This file

## Tech Stack

- **UI Framework:** SwiftUI
- **Backend:** Firebase (Firestore, Authentication, Realtime Database)
- **State Management:** @StateObject, @EnvironmentObject (SwiftUI native)
- **Networking:** URLSession + Firebase SDK
- **Local Storage:** UserDefaults, Keychain
- **Notifications:** UserNotifications framework
- **Testing:** XCTest

## Setup Instructions

### Prerequisites
- macOS 12+ with Xcode 13+ (or Command Line Tools)
- Swift 5.7+
- CocoaPods (for Firebase dependency management)
- Firebase project credentials (GoogleService-Info.plist)

### 1. Install Dependencies

```bash
# Using CocoaPods
cd ProperDisciplineApp
pod init
# Edit Podfile to include Firebase dependencies
pod install
```

### 2. Configure Firebase

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project: "ProperDisciplineApp"
3. Add iOS app with bundle ID: `com.properProductivePigeons.app`
4. Download `GoogleService-Info.plist`
5. Add to Xcode project (under ProperDisciplineApp target)

### 3. Build & Run

**In Xcode:**
- Open `ProperDisciplineApp.xcworkspace` (not .xcodeproj)
- Select target device
- Press Cmd+R to build and run

**On Command Line:**
```bash
xcodebuild -workspace ProperDisciplineApp.xcworkspace -scheme ProperDisciplineApp -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build build
```

## Development Workflow

### Phase 1: MVP (Week 1-2)
- [ ] Authentication (Firebase Auth)
- [ ] Nest creation & invite code
- [ ] Task CRUD
- [ ] Daily check-in UI
- [ ] Streak & XP calculation
- [ ] Basic Dashboard

### Phase 2: Rewards & Animations (Week 2-3)
- [ ] Checkpoint unlocks
- [ ] Deserving display & tracking
- [ ] Checkpoint celebration animations
- [ ] Solo Levelling theme refinements

### Phase 3: Sync & Polish (Week 3)
- [ ] Real-time sync between pigeons
- [ ] Notifications
- [ ] Settings & profile customization
- [ ] Bug fixes & optimizations

## Testing

Run tests with:
```bash
xcodebuild test -workspace ProperDisciplineApp.xcworkspace -scheme ProperDisciplineApp
```

## Deployment (Testing)

For internal testing distribution:
1. Create provisioning profiles in Apple Developer
2. Build for testflight or direct IPA distribution
3. Install on test devices

## Future Enhancements

- Health app integration (steps, workouts)
- Advanced analytics & reporting
- Couple achievements/global leaderboards
- Custom checkpoint formulas per task
- Multiple nests support
- Dark/light theme toggle

## Contact & Questions

Reach out with any clarifications on the spec or architecture.
