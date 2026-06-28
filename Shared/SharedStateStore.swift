import Foundation

/// App Group storage for cross-target state (main app + future extensions).
final class SharedStateStore {
    static let shared = SharedStateStore()

    private let defaults: UserDefaults?

    private init() {
        defaults = UserDefaults(suiteName: AppConstants.appGroupID)
    }

    var masterEnabled: Bool {
        get {
            if defaults?.object(forKey: AppConstants.masterEnabledKey) == nil {
                return true
            }
            return defaults?.bool(forKey: AppConstants.masterEnabledKey) ?? true
        }
        set {
            defaults?.set(newValue, forKey: AppConstants.masterEnabledKey)
            print("[SharedStateStore] masterEnabled = \(newValue)")
        }
    }
}
