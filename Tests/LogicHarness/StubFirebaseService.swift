import Foundation

/// In-memory stand-in for FirebaseService so the app's real models and view models can run on a Mac
/// without Firebase or Xcode. It mirrors only the API surface the view models use.
final class FirebaseService: NSObject, ObservableObject {
    static let shared = FirebaseService()
    
    @Published var currentPigeon: Pigeon?
    @Published var currentNest: Nest?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    
    // Programmable behaviour
    var tasks: [Task] = []
    var completions: [String: [String: [TaskCompletion]]] = [:]   // taskId -> pigeonId -> completions
    var claims: [ClaimedDeserving] = []
    var failCompletionFetchFor: Set<String> = []                    // pigeonIds whose fetch fails
    var authShouldSucceed = true
    var authError = "The password is invalid."
    var nestShouldSucceed = true
    var signInCalls = 0
    var signUpCalls = 0
    
    func signUp(email: String, password: String, name: String, avatar: String) async -> Bool {
        signUpCalls += 1
        errorMessage = nil
        if !authShouldSucceed { errorMessage = authError; return false }
        return true
    }
    func signIn(email: String, password: String) async -> Bool {
        signInCalls += 1
        errorMessage = nil
        if !authShouldSucceed { errorMessage = authError; return false }
        return true
    }
    func signOut() { isAuthenticated = false }
    
    func createNest(name: String, theme: String) async -> Nest? {
        errorMessage = nil
        if !nestShouldSucceed { errorMessage = "Permission denied"; return nil }
        return Nest(id: "n", name: name, theme: theme, createdBy: "me", pigeons: ["me"], inviteCode: "ABC123",
                    inviteExpiresAt: Date().addingTimeInterval(86_400), createdAt: Date(), updatedAt: Date())
    }
    func joinNest(inviteCode: String) async -> Nest? {
        errorMessage = nil
        if !nestShouldSucceed { errorMessage = "Invalid invite code"; return nil }
        return Nest(id: "n", name: "n", theme: "t", createdBy: "x", pigeons: ["x", "me"], inviteCode: inviteCode,
                    inviteExpiresAt: Date().addingTimeInterval(86_400), createdAt: Date(), updatedAt: Date())
    }
    
    func createTask(nestId: String, name: String, description: String, type: Task.TaskType, frequency: Task.Frequency, checkpoints: [Checkpoint]) async -> Task? { nil }
    func fetchTasks(nestId: String) async -> [Task]? { tasks }
    func markTaskComplete(taskId: String, pigeonId: String, date: String, isComplete: Bool) async {}
    func fetchCompletions(taskId: String, pigeonId: String) async -> [TaskCompletion]? {
        if failCompletionFetchFor.contains(pigeonId) { return nil }
        return completions[taskId]?[pigeonId] ?? []
    }
    func fetchClaimedDeservings(pigeonId: String) async -> [ClaimedDeserving]? { claims }
}
