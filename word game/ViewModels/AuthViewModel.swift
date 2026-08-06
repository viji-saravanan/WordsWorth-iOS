import Combine
import Foundation

struct UserProfile: Codable, Equatable {
    let id: String
    let displayName: String?
}

struct AuthState: Equatable {
    var user: UserProfile?
    var isLoading: Bool
    var error: String?
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var state: AuthState
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Keys.user),
           let user = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.state = AuthState(user: user, isLoading: false, error: nil)
        } else {
            self.state = AuthState(user: nil, isLoading: false, error: nil)
        }
    }

    func startSignIn() {
        state.isLoading = true
        state.error = nil
    }

    func signInWithGoogle() {
        startSignIn()
        // TODO: Replace with Google Sign-In once client credentials are configured.
        signIn(userId: "google-\(UUID().uuidString)", displayName: "Google User")
    }

    func signIn(userId: String, displayName: String?) {
        let user = UserProfile(id: userId, displayName: displayName)
        state = AuthState(user: user, isLoading: false, error: nil)
        if let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: Keys.user)
        }
    }

    func signInOffline() {
        signIn(userId: "offline-\(UUID().uuidString)", displayName: "Guest")
    }

    func setError(_ message: String) {
        state.isLoading = false
        state.error = message
    }

    func signOut() {
        defaults.removeObject(forKey: Keys.user)
        state = AuthState(user: nil, isLoading: false, error: nil)
    }

    private enum Keys {
        static let user = "wordgame_user_profile"
    }
}
