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

## Website deployment (Render)

The responsive website in [`web/`](./web/) uses Firebase Authentication and the same Firestore collections as the iOS app. It supports account sign-in/sign-up, creating or joining a nest, personal and shared daily/weekly goals, check-ins, and monthly activity history. A Firebase Web app is required in addition to the registered iOS app; both can use the same Firebase project.

1. In Firebase Console, open the same project used by iOS. Under **Project settings → General → Your apps**, select **Add app → Web** and register a web app.
2. In **Authentication → Sign-in method**, enable **Email/Password**. Confirm the project's Firestore database and the rules in [`firestore.rules`](./firestore.rules) are deployed.
3. In **Authentication → Settings → Authorized domains**, add the Render domain after the first deployment (for example, `proper-productive-pigeons.onrender.com`).
4. In Render, choose **New → Blueprint**, connect this repository, and select [`render.yaml`](./render.yaml). Map Firebase's `apiKey`, `authDomain`, `projectId`, `storageBucket`, `messagingSenderId`, and `appId` values to `FIREBASE_API_KEY`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_PROJECT_ID`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_MESSAGING_SENDER_ID`, and `FIREBASE_APP_ID`, respectively. The Firebase web config is client-visible by design; never use a service-account key or Admin SDK credentials here.
5. Deploy. Render runs `scripts/write-firebase-config.mjs` to generate the ignored client config and publishes the `web/` directory. Sign up or sign in with the same account used in iOS to access its profile, nest, goals, and check-ins.

The Firebase Spark (no-cost) plan is generally enough to get started; Firebase applies usage quotas and may require billing if the project outgrows them. Render's free static sites can host the frontend, subject to Render's current plan limits. No Firebase Admin credentials or paid app server are required.

For local development, set the same six `FIREBASE_*` variables in the shell and run `node scripts/write-firebase-config.mjs`, then serve the `web/` directory from a local HTTP server. Do not open `index.html` as a `file://` URL: browser modules and Firebase Auth require an HTTP origin.

## Future Enhancements

- Health app integration (steps, workouts)
- Advanced analytics & reporting
- Couple achievements/global leaderboards
- Custom checkpoint formulas per task
- Multiple nests support
- Dark/light theme toggle

## Contact & Questions

Reach out with any clarifications on the spec or architecture.
