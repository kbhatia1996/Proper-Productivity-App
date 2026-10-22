import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import UIKit

/// Firebase access for auth, nests, tasks and completions.
/// `FirebaseApp.configure()` is called once from the App entry point, before this singleton is first used.
class FirebaseService: NSObject, ObservableObject {
    static let shared = FirebaseService()
    
    /// A nest is a couple: the creator plus one partner
    static let maxNestMembers = 2
    
    @Published var currentPigeon: Pigeon?
    @Published var currentNest: Nest?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    
    // Computed so it is only touched after FirebaseApp.configure()
    private var db: Firestore { Firestore.firestore() }
    private var authHandle: NSObjectProtocol?
    private var pigeonListener: ListenerRegistration?
    
    override init() {
        super.init()
        setupAuthStateListener()
    }
    
    // MARK: - Authentication
    
    private func setupAuthStateListener() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            // Always drop the previous user's listener first so it can't write stale state
            self.pigeonListener?.remove()
            self.pigeonListener = nil
            
            if let user = user {
                self.isAuthenticated = true
                self.fetchCurrentPigeon(uid: user.uid)
            } else {
                self.isAuthenticated = false
                self.currentPigeon = nil
                self.currentNest = nil
            }
        }
    }
    
    /// Returns true on success; on failure `errorMessage` explains why.
    @discardableResult
    func signUp(email: String, password: String, name: String, avatar: String) async -> Bool {
        errorMessage = nil
        let authResult: AuthDataResult
        do {
            authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
        
        let pigeon = Pigeon(
            id: authResult.user.uid,
            email: email,
            name: name,
            avatar: avatar,
            createdAt: Date(),
            lastActiveAt: Date()
        )
        do {
            try await db.collection("pigeons").document(pigeon.id).setData(from: pigeon)
            self.currentPigeon = pigeon
            return true
        } catch {
            // Edge case: account exists but profile write failed. Remove the account so the user can retry
            // with the same email instead of being stuck signed in without a profile.
            errorMessage = error.localizedDescription
            try? await authResult.user.delete()
            return false
        }
    }
    
    @discardableResult
    func signIn(email: String, password: String) async -> Bool {
        errorMessage = nil
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    /// Signs in (or up) with Google and creates the profile on first use. Returns false if cancelled or failed;
    /// on failure `errorMessage` explains why (it stays nil when the user just closes the Google sheet).
    @MainActor
    @discardableResult
    func signInWithGoogle(avatar: String) async -> Bool {
        errorMessage = nil
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Google sign-in isn't set up. Enable Google in Firebase Authentication, then download a fresh GoogleService-Info.plist."
            return false
        }
        guard let presenter = Self.topViewController() else {
            errorMessage = "Couldn't open Google sign-in. Please try again."
            return false
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google didn't return a sign-in token. Please try again."
                return false
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
            let authResult = try await Auth.auth().signIn(with: credential)
            try await createProfileIfMissing(for: authResult.user, avatar: avatar)
            return true
        } catch {
            let nsError = error as NSError
            if nsError.domain == kGIDSignInErrorDomain && nsError.code == GIDSignInError.canceled.rawValue {
                return false
            }
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    private func createProfileIfMissing(for user: User, avatar: String) async throws {
        let ref = db.collection("pigeons").document(user.uid)
        guard !(try await ref.getDocument()).exists else { return }
        let email = user.email ?? ""
        let fallbackName = email.split(separator: "@").first.map(String.init) ?? "Pigeon"
        let displayName = (user.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let pigeon = Pigeon(
            id: user.uid,
            email: email,
            name: displayName.isEmpty ? fallbackName : displayName,
            avatar: avatar,
            createdAt: Date(),
            lastActiveAt: Date()
        )
        try await ref.setData(from: pigeon)
    }
    
    @MainActor
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Pigeon Operations
    
    private func fetchCurrentPigeon(uid: String) {
        pigeonListener = db.collection("pigeons").document(uid).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            guard let snapshot = snapshot, snapshot.exists else { return }
            do {
                let pigeon = try snapshot.data(as: Pigeon.self)
                self.currentPigeon = pigeon
                
                // Restore the nest after a relaunch / sign-in
                if let nestId = pigeon.nestId {
                    if self.currentNest?.id != nestId {
                        _Concurrency.Task { await self.fetchNest(nestId: nestId) }
                    }
                } else {
                    self.currentNest = nil
                }
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Nest Operations
    
    func createNest(name: String, theme: String) async -> Nest? {
        guard let pigeon = currentPigeon else { return nil }
        
        let nestId = UUID().uuidString
        let inviteCode = generateInviteCode()
        let inviteExpiresAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        
        let nest = Nest(
            id: nestId,
            name: name,
            theme: theme,
            createdBy: pigeon.id,
            pigeons: [pigeon.id],
            inviteCode: inviteCode,
            inviteExpiresAt: inviteExpiresAt,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        do {
            try await db.collection("nests").document(nest.id).setData(from: nest)
            try await db.collection("pigeons").document(pigeon.id).updateData([
                "nest_id": nest.id
            ])
            self.currentNest = nest
            return nest
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    func joinNest(inviteCode: String) async -> Nest? {
        guard let pigeon = currentPigeon else { return nil }
        errorMessage = nil
        
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else {
            errorMessage = "Invite code is required"
            return nil
        }
        
        do {
            let querySnapshot = try await db.collection("nests")
                .whereField("invite_code", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()
            
            guard let doc = querySnapshot.documents.first else {
                errorMessage = "Invalid invite code"
                return nil
            }
            
            let nest = try doc.data(as: Nest.self)
            
            guard nest.isInviteValid else {
                errorMessage = "Invite code expired"
                return nil
            }
            
            // Edge cases: joining twice, or a nest that already has both partners
            if nest.pigeons.contains(pigeon.id) {
                try await db.collection("pigeons").document(pigeon.id).updateData(["nest_id": nest.id])
                self.currentNest = nest
                return nest
            }
            guard nest.pigeons.count < Self.maxNestMembers else {
                errorMessage = "This nest is already full"
                return nil
            }
            
            try await db.collection("nests").document(nest.id).updateData([
                "pigeons": FieldValue.arrayUnion([pigeon.id]),
                "updated_at": Date()
            ])
            try await db.collection("pigeons").document(pigeon.id).updateData([
                "nest_id": nest.id
            ])
            
            var joinedNest = nest
            joinedNest.pigeons = nest.pigeons + [pigeon.id]
            self.currentNest = joinedNest
            return joinedNest
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    func fetchNest(nestId: String) async {
        do {
            let doc = try await db.collection("nests").document(nestId).getDocument()
            self.currentNest = try doc.data(as: Nest.self)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Task Operations
    
    func createTask(nestId: String, name: String, description: String, type: Task.TaskType, frequency: Task.Frequency, checkpoints: [Checkpoint]) async -> Task? {
        guard let pigeon = currentPigeon else { return nil }
        
        let taskId = UUID().uuidString
        let task = Task(
            id: taskId,
            nestId: nestId,
            name: name,
            description: description,
            taskType: type,
            frequency: frequency,
            createdBy: pigeon.id,
            createdAt: Date(),
            updatedAt: Date(),
            checkpoints: checkpoints
        )
        
        do {
            try await db.collection("tasks").document(task.id).setData(from: task)
            return task
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    func fetchTasks(nestId: String) async -> [Task]? {
        do {
            let querySnapshot = try await db.collection("tasks")
                .whereField("nest_id", isEqualTo: nestId)
                .getDocuments()
            
            return querySnapshot.documents.compactMap { try? $0.data(as: Task.self) }
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Task Completion
    
    func markTaskComplete(taskId: String, pigeonId: String, date: String, isComplete: Bool) async {
        let completionId = "\(taskId)_\(pigeonId)_\(date)"
        let ref = db.collection("task_completions").document(completionId)
        
        do {
            // Only count real state changes so repeated taps can't inflate the total
            let previous = try await ref.getDocument().data()?["is_complete"] as? Bool ?? false
            try await ref.setData([
                "id": completionId,
                "task_id": taskId,
                "pigeon_id": pigeonId,
                "date": date,
                "is_complete": isComplete,
                "created_at": Date(),
                "updated_at": Date()
            ])
            
            let delta = (isComplete ? 1 : 0) - (previous ? 1 : 0)
            if delta != 0 {
                try await db.collection("pigeons").document(pigeonId).updateData([
                    "total_tasks_completed": FieldValue.increment(Int64(delta)),
                    "last_active_at": Date()
                ])
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func fetchClaimedDeservings(pigeonId: String) async -> [ClaimedDeserving]? {
        do {
            let snapshot = try await db.collection("claimed_deservings")
                .whereField("pigeon_id", isEqualTo: pigeonId)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: ClaimedDeserving.self) }
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    func fetchCompletions(taskId: String, pigeonId: String) async -> [TaskCompletion]? {
        do {
            let querySnapshot = try await db.collection("task_completions")
                .whereField("task_id", isEqualTo: taskId)
                .whereField("pigeon_id", isEqualTo: pigeonId)
                .getDocuments()
            
            return querySnapshot.documents.compactMap { try? $0.data(as: TaskCompletion.self) }
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Helper Functions
    
    private func generateInviteCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}
