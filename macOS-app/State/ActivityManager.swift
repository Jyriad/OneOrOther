import Foundation

/// Holds a ProcessInfo activity assertion so macOS does not "App Nap" the
/// menu-bar app while enforcement is active. App Nap throttles background
/// apps and was interrupting the Bluetooth link, causing repeated timeouts.
@MainActor
final class ActivityManager {
    private var token: NSObjectProtocol?

    var isActive: Bool { token != nil }

    func begin() {
        guard token == nil else { return }
        token = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .suddenTerminationDisabled, .automaticTerminationDisabled],
            reason: "Maintaining Bluetooth link with iPhone for enforcement"
        )
        Log.line("ActivityManager", "App Nap prevention ON")
    }

    func end() {
        guard let token else { return }
        ProcessInfo.processInfo.endActivity(token)
        self.token = nil
        Log.line("ActivityManager", "App Nap prevention OFF")
    }
}
