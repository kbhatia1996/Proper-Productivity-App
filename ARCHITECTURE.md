# Proper Discipline App – Architecture Overview

## 🏗️ MVVM Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Views (SwiftUI)                          │
│  ┌──────────────┐  ┌─────────────────┐  ┌───────────────────┐  │
│  │ Auth View    │  │ Nest Setup View │  │  Dashboard View   │  │
│  └──────────────┘  └─────────────────┘  └───────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ViewModels (@Observable)                     │
│  ┌──────────────┐  ┌─────────────┐  ┌────────────────────────┐ │
│  │ AuthViewModel│  │ NestViewModel│  │ TaskViewModel          │ │
│  └──────────────┘  └─────────────┘  └────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Services (Business Logic)                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │        FirebaseService (Auth + Firestore Sync)          │  │
│  │  ├─ signUp / signIn / signOut                           │  │
│  │  ├─ createNest / joinNest / fetchNest                   │  │
│  │  ├─ createTask / fetchTasks                             │  │
│  │  ├─ markTaskComplete / fetchCompletions                 │  │
│  │  └─ updatePigeonXP                                      │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              Models (Data Structures - Codable)                 │
│  ┌────────┐ ┌──────┐ ┌──────┐ ┌────────────┐ ┌─────────────┐  │
│  │ Pigeon │ │ Nest │ │ Task │ │ Checkpoint │ │  Deserving  │  │
│  └────────┘ └──────┘ └──────┘ └────────────┘ └─────────────┘  │
│  ┌─────────────────┐ ┌──────────┐ ┌──────────┐                 │
│  │ TaskCompletion  │ │  Streak  │ │Achievement                 │
│  └─────────────────┘ └──────────┘ └──────────┘                 │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              Firebase (Backend Infrastructure)                  │
│  ┌──────────────────┐  ┌──────────────────────────────────────┐ │
│  │ Firebase Auth    │  │ Firestore (Real-time NoSQL DB)      │ │
│  │ ├─ Email/Pass    │  │ ├─ pigeons collection               │ │
│  │ ├─ User Sessions │  │ ├─ nests collection                 │ │
│  │ └─ Auth State    │  │ ├─ tasks collection                 │ │
│  │                  │  │ ├─ task_completions collection      │ │
│  │                  │  │ ├─ streaks collection               │ │
│  │                  │  │ └─ achievements collection           │ │
│  └──────────────────┘  └──────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📊 Data Flow

### Sign Up Flow
```
User Input
    │
    ▼
AuthView
    │
    ▼
AuthViewModel.signUp()
    │
    ▼
FirebaseService.signUp()
    │
    ├─ Create Auth Account (Firebase Auth)
    │
    └─ Create Pigeon Document (Firestore)
        │
        ▼
    @Published currentPigeon updated
    isAuthenticated = true
        │
        ▼
    Navigate to NestSetupView
```

### Create Task Flow
```
TaskForm Input
    │
    ▼
NewTaskSheet
    │
    ▼
TaskViewModel.createTask()
    │
    ├─ Build Checkpoints with Deservings
    │
    ├─ FirebaseService.createTask()
    │
    ├─ Write Task to Firestore
    │
    └─ Fetch Updated Tasks List
        │
        ▼
    @Published tasks updated
        │
        ▼
    DashboardView re-renders
```

### Task Completion Flow (Ready to Build)
```
User Taps "Complete Task"
    │
    ▼
TaskViewModel.markTaskComplete()
    │
    ├─ FirebaseService.markTaskComplete()
    │
    ├─ Write TaskCompletion to Firestore
    │
    └─ [TODO] Calculate Streak
        │
        ├─ [TODO] Check if Checkpoint Hit
        │
        ├─ [TODO] Award XP
        │
        └─ [TODO] Trigger Celebration Animation
            │
            ▼
        [TODO] Notify Partner (Real-time Sync)
```

---

## 🎨 UI Component Hierarchy

```
ProperDisciplineAppApp (Root)
│
├─ AuthenticationView
│  └─ AuthViewModel
│     └─ SignUp/SignIn Forms
│
├─ NestSetupView (if authenticated but no nest)
│  ├─ CreateNestSheet
│  │  └─ NestViewModel
│  │
│  └─ JoinNestSheet
│     └─ NestViewModel
│
└─ DashboardView (if authenticated + in nest)
   ├─ TaskViewModel
   ├─ TaskViewModel
   │
   ├─ PigeonCard
   │  └─ Shows name, rank, XP, avatar
   │
   ├─ NestCard
   │  └─ Shows nest name, invite code
   │
   ├─ TaskListView
   │  └─ TaskCardView (for each task)
   │     ├─ Task name & description
   │     ├─ Next checkpoint info
   │     └─ Completion toggle
   │
   └─ NewTaskSheet
      └─ Creates task + checkpoints + deservings
```

---

## 🔄 Real-Time Data Sync (Firebase Listeners)

### Current Implementation
- AuthStateListener on app launch (checks if user logged in)
- Manual fetches for tasks & nest data

### To Add (Phase 2)
```swift
// Listen to current pigeon updates
db.collection("pigeons")
  .document(currentPigeonId)
  .addSnapshotListener { snapshot, error in
    // Update @Published currentPigeon
    // UI automatically re-renders
  }

// Listen to partner's task completions (shared tasks)
db.collection("task_completions")
  .whereField("nestId", isEqualTo: currentNestId)
  .addSnapshotListener { snapshot, error in
    // Update local task completion state
    // Show partner's progress in real-time
  }

// Listen to checkpoint achievements
db.collection("achievements")
  .whereField("nestId", isEqualTo: currentNestId)
  .addSnapshotListener { snapshot, error in
    // Trigger celebration when partner gets achievement
    // Send local notification
  }
```

---

## 🎯 State Management Pattern

```swift
// AuthView Example
@StateObject var authViewModel = AuthViewModel()  // Lifecycle tied to view

class AuthViewModel: ObservableObject {
    @Published var email = ""                       // UI listens to changes
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    func signIn() async {
        isLoading = true                            // UI shows spinner
        await firebaseService.signIn(...)
        isLoading = false                           // UI dismisses spinner
    }
}
```

**Key Pattern:**
- ViewModels hold @Published properties
- Views observe changes via @ObservedObject
- Changes automatically trigger SwiftUI re-render

---

## 🔐 Dependency Injection

Currently using SwiftUI environment:

```swift
// App Entry Point
FirebaseService.shared  // Singleton

// Passed to views
.environmentObject(firebaseService)  // Makes available to all child views
.environmentObject(authViewModel)

// Accessed in views
@EnvironmentObject var firebaseService: FirebaseService
```

---

## 📦 File Organization

```
ProperDisciplineApp/
│
├── App/
│   └── ProperDisciplineAppApp.swift          # Entry + Navigation
│
├── Models/                                    # Pure data, no logic
│   ├── Pigeon.swift
│   ├── Nest.swift
│   ├── Task.swift
│   ├── Checkpoint.swift
│   ├── TaskCompletion.swift
│   └── Achievement.swift
│
├── ViewModels/                                # Business logic, state mgmt
│   ├── AuthViewModel.swift
│   ├── NestViewModel.swift
│   └── TaskViewModel.swift
│
├── Services/                                  # External integrations
│   └── FirebaseService.swift                 # All Firebase operations
│
├── Views/                                     # UI Components
│   ├── AuthenticationView.swift
│   ├── NestSetupView.swift
│   └── DashboardView.swift
│
├── Utils/                                     # Utilities & Design System
│   └── SoloLevellingTheme.swift              # Colors, buttons, cards
│
└── Assets/                                    # Images, colors, fonts
    ├── Colors.xcassets
    └── Images/
```

---

## 🧪 Testing Structure (Ready to Add)

```
ProperDisciplineAppTests/
│
├── ViewModelTests/
│   ├── AuthViewModelTests.swift
│   ├── NestViewModelTests.swift
│   └── TaskViewModelTests.swift
│
├── ServiceTests/
│   └── FirebaseServiceTests.swift
│
├── ModelTests/
│   ├── PigeonTests.swift
│   └── TaskTests.swift
│
└── UITests/
    ├── AuthenticationUITests.swift
    └── DashboardUITests.swift
```

---

## 🚀 Scalability Notes

### Current Limits
- Single Firestore collection queries (good for MVP)
- No offline caching (will need when app grows)
- No pagination (fine for ~20 tasks per pigeon)

### Future Optimizations
- Implement `FirebaseFirestoreOfflineSupport`
- Add pagination for large task lists
- Batch writes for multiple operations
- Index creation for complex queries
- Local caching layer with URLSessionCache

---

## 🔗 Key Integration Points

| Component | Integrates With | Purpose |
|---|---|---|
| FirebaseService | All ViewModels | Auth, data CRUD, sync |
| AuthViewModel | AuthenticationView | Login/signup flows |
| NestViewModel | NestSetupView | Nest creation/joining |
| TaskViewModel | DashboardView | Task management |
| SoloLevellingTheme | All Views | Consistent styling |

---

**Architecture Status**: ✅ Solid foundation, ready for feature expansion
