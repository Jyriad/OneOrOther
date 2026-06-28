import Foundation

/// App Group storage for cross-target state (main app + future extensions).
final class SharedStateStore {
    static let shared = SharedStateStore()

    private let defaults: UserDefaults
    private let usesAppGroup: Bool

    private init() {
        if let groupDefaults = UserDefaults(suiteName: AppConstants.appGroupID) {
            defaults = groupDefaults
            usesAppGroup = true
            Log.boot("SharedStateStore using App Group \(AppConstants.appGroupID)")
        } else {
            defaults = .standard
            usesAppGroup = false
            Log.line("SharedStateStore", "App Group unavailable — using standard defaults for this session")
        }
    }

    var masterEnabled: Bool {
        get {
            if defaults.object(forKey: AppConstants.masterEnabledKey) == nil {
                return true
            }
            return defaults.bool(forKey: AppConstants.masterEnabledKey)
        }
        set {
            defaults.set(newValue, forKey: AppConstants.masterEnabledKey)
            Log.line("SharedStateStore", "masterEnabled = \(newValue) (appGroup=\(usesAppGroup))")
        }
    }
}
