# Copilot instructions

## Build and test

- `project.yml` is the XcodeGen source of truth; the generated `.xcodeproj` is ignored. Generate it with `xcodegen generate`, then build the app with:
  `xcodebuild -project ProperDisciplineApp.xcodeproj -scheme ProperDisciplineApp -destination 'generic/platform=iOS Simulator' build`
- Firebase is resolved through Swift Package Manager from `project.yml`. For a working app launch, add the Firebase project's `GoogleService-Info.plist` as described in [INSTALL_ON_IPHONE.md](../INSTALL_ON_IPHONE.md); it is intentionally gitignored.
- Run the logic suite on macOS with `Tests/run_logic_tests.sh`. It compiles the real models and view models against `Tests/LogicHarness/StubFirebaseService.swift`, needs the Swift toolchain but not Firebase or Xcode, and runs scenarios under four time zones.
- The logic harness has no test-name filter or separate XCTest target. Scenarios and assertions live in `Tests/LogicHarness/main.swift` and run as one suite; there is currently no supported command to run just one assertion or scenario.
- CI runs the logic suite before generating and archiving the iOS app. The archive workflow also requires the `GOOGLE_SERVICE_INFO_PLIST_BASE64` GitHub Actions secret; see [build-ios.yml](./workflows/build-ios.yml) and [INSTALL_ON_IPHONE.md](../INSTALL_ON_IPHONE.md).

## Architecture

- This is a SwiftUI iOS app organized around models, observable view models, and views. `ProperDisciplineAppApp` is the root router: it checks Firebase configuration and authentication, waits for the user's profile, then routes to nest setup or the main tabs.
- `FirebaseService.shared` owns Firebase Auth and Firestore access and publishes the current pigeon, nest, authentication state, and errors. The root and feature views pass it through SwiftUI's environment; feature view models call the service for reads and writes.
- After a user joins a nest, `MainTabView` hosts Home and Activity and shares one `TaskViewModel` between the dashboard and calendar. `CalendarViewModel` derives progress from tasks, nest membership, task completions, and claimed rewards; changing the period or personal/shared filter is an in-memory recalculation, not a new fetch.
- Personal tasks count only for their creator. Shared-task progress is divided among nest members, so one member's check-in is partial credit. Weekly tasks are scheduled on the weekday they were created.
- Appearance and reward-reminder preferences are persisted with `@AppStorage`. `RewardNotificationService` owns the opt-in, daily local-time reminder and reconciles it against task progress; keep it in sync when task completion or reward-threshold behavior changes.
- Firestore document access and authentication live in `Services/FirebaseService.swift`; Firestore access constraints are separately expressed in the root `firestore.rules`. Keep changes to data access consistent with those rules.

## Repository conventions

- View models use `ObservableObject`/`@Published` and are generally `@MainActor`; asynchronous Firebase operations are exposed by `FirebaseService`. Surface operation failures through the existing published error-message state so views can show them.
- Codable models explicitly map Swift properties to Firestore's snake_case fields with `CodingKeys`. Preserve those persisted field names when changing models, and account for older stored documents where model decoding already provides defaults.
- Profile avatars are stored as emoji strings; `Pigeon.avatarEmoji` maps the original `pigeon_1`–`pigeon_4` values for profiles created before the emoji picker.
- Calendar calculations use `Calendar` and date keys formatted as `yyyy-MM-dd`. The test harness checks timezone and daylight-saving behavior; avoid replacing calendar-aware calculations with fixed 24-hour arithmetic.
- The logic harness compiles production model and view-model sources while substituting a test-only `FirebaseService` with the same API surface. If a view model starts using a new service method or property, keep the stub in sync.
- Shared visual colors and styling are centralized in `Utils/SoloLevellingTheme.swift`; its adaptive colors follow the persisted dark/light appearance choice. Reuse it for app UI rather than introducing parallel palette values.
