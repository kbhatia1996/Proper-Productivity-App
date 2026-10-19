import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

/// Simplified Firebase service for Firestore operations
class FirebaseService: NSObject, ObservableObject {
    static let shared = FirebaseService()
    
    @Published var currentPigeon: Pigeon?
    @Published var currentNest: Nest?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    override init() {
        super.init()
        FirebaseApp.configure()
        setupAuthStateListener()
    }
    
    // MARK: - Authentication
    
    private func setupAuthStateListener() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                self?.isAuthenticated = true
                self?.fetchCurrentPigeon(uid: user.uid)
            } else {
                self?.isAuthenticated = false
                self?.currentPigeon = nil
                self?.currentNest = nil
            }
        }
    }
    
    func signUp(email: String, password: String, name: String, avatar: String) async {
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            let pigeon = Pigeon(
                id: authResult.user.uid,
                email: email,
                name: name,
                avatar: avatar,
                createdAt: Date(),
                lastActiveAt: Date()
            )
            try await db.collection("pigeons").document(pigeon.id).setData(from: pigeon)
            self.currentPigeon = pigeon
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func signIn(email: String, password: String) async {
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Pigeon Operations
    
    private func fetchCurrentPigeon(uid: String) {
        db.collection("pigeons").document(uid).addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                return
            }
            
            guard let data = snapshot?.data() else { return }
            do {
                self?.currentPigeon = try Firestore.Decoder().decode(Pigeon.self, from: data)
            } catch {
                self?.errorMessage = error.localizedDescription
            }
        }
    }
    
    func updatePigeonXP(pigeonId: String, xpGain: Int) async {
        guard let pigeon = currentPigeon else { return }
        let newXP = pigeon.xp + xpGain
        let newRank = Pigeon.rankFromXP(newXP)
        
        do {
            try await db.collection("pigeons").document(pigeonId).updateData([
                "xp": newXP,
                "rank": newRank,
                "last_active_at": Date()
            ])
        } catch {
            errorMessage = error.localizedDescription
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
        
        do {
            let querySnapshot = try await db.collection("nests")
                .whereField("invite_code", isEqualTo: inviteCode)
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
            
            var updatedPigeons = nest.pigeons
            updatedPigeons.append(pigeon.id)
            
            try await db.collection("nests").document(nest.id).updateData([
                "pigeons": updatedPigeons,
                "updated_at": Date()
            ])
            
            try await db.collection("pigeons").document(pigeon.id).updateData([
                "nest_id": nest.id
            ])
            
            var joinedNest = nest
            joinedNest.pigeons = updatedPigeons
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
            
            return try querySnapshot.documents.compactMap { try $0.data(as: Task.self) }
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Task Completion
    
    func markTaskComplete(taskId: String, pigeonId: String, date: String, isComplete: Bool) async {
        let completionId = "\(taskId)_\(pigeonId)_\(date)"
        
        do {
            try await db.collection("task_completions").document(completionId).setData([
                "task_id": taskId,
                "pigeon_id": pigeonId,
                "date": date,
                "is_complete": isComplete,
                "created_at": Date(),
                "updated_at": Date()
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func fetchCompletions(taskId: String, pigeonId: String) async -> [TaskCompletion]? {
        do {
            let querySnapshot = try await db.collection("task_completions")
                .whereField("task_id", isEqualTo: taskId)
                .whereField("pigeon_id", isEqualTo: pigeonId)
                .getDocuments()
            
            return try querySnapshot.documents.compactMap { try $0.data(as: TaskCompletion.self) }
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
