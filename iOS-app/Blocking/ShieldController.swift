import Foundation
import ManagedSettings

@MainActor
final class ShieldController: ObservableObject {
    @Published private(set) var isShieldActive = false

    private let store = ManagedSettingsStore(named: .init("oneorother-nuclear"))

    func applyShield() {
        guard !isShieldActive else { return }
        store.shield.applicationCategories = .all()
        store.shield.webDomainCategories = .all()
        isShieldActive = true
        print("[ShieldController] whole-phone shield applied")
    }

    func removeShield() {
        guard isShieldActive else { return }
        store.clearAllSettings()
        isShieldActive = false
        print("[ShieldController] shield removed")
    }
}
