import FamilyControls
import Foundation

@MainActor
final class AuthorizationManager: ObservableObject {
    @Published private(set) var isAuthorized = false
    @Published private(set) var authorizationError: String?

    init() {
        refreshStatus()
    }

    func refreshStatus() {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
            authorizationError = nil
            print("[AuthorizationManager] Screen Time authorization approved")
        } catch {
            isAuthorized = false
            authorizationError = error.localizedDescription
            print("[AuthorizationManager] authorization failed: \(error.localizedDescription)")
        }
    }
}
