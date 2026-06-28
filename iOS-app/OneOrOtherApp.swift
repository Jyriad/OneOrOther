import SwiftUI
import UIKit

@main
struct OneOrOtherApp: App {
    @StateObject private var coordinator = AppCoordinator()

    init() {
        Log.boot("OneOrOtherApp launching")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
        }
    }
}

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var masterEnabled: Bool
    @Published private(set) var blockDecision: BlockDecision = .clear(reason: "Starting up")
    @Published private(set) var statusSummary = "Initializing…"
    @Published private(set) var isStarted = false

    let phoneState = PhoneStateMonitor()
    let linkManager = PhoneLinkManager()
    let authManager = AuthorizationManager()
    let shieldController = ShieldController()

    private var heartbeatTimer: Timer?
    private var decisionTimer: Timer?
    private var isAppInForeground = true
    private var lifecycleObservers: [NSObjectProtocol] = []

    init() {
        Log.boot("AppCoordinator init begin")
        masterEnabled = SharedStateStore.shared.masterEnabled
        linkManager.onRemoteStateUpdated = { [weak self] in
            Task { @MainActor in
                self?.reevaluate()
            }
        }
        observeAppLifecycle()
        Log.boot("AppCoordinator init complete")
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        Log.boot("AppCoordinator starting BLE + decision timers")
        linkManager.start()
        startTimers()
        reevaluate()
    }

    private func observeAppLifecycle() {
        let center = NotificationCenter.default
        lifecycleObservers.append(
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isAppInForeground = true
                    Log.line("AppCoordinator", "app became active — shield paused while in OneOrOther")
                    self?.reevaluate()
                }
            }
        )
        lifecycleObservers.append(
            center.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isAppInForeground = false
                    Log.line("AppCoordinator", "app resigned active — shield may apply")
                    self?.reevaluate()
                }
            }
        )
    }

    deinit {
        lifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func startTimers() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.heartbeatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.linkManager.updateLocalState(
                    deviceActive: self.phoneState.isUnlocked,
                    masterEnabled: self.masterEnabled
                )
            }
        }
        decisionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.reevaluate()
            }
        }
    }

    func setMasterEnabled(_ enabled: Bool) {
        masterEnabled = enabled
        SharedStateStore.shared.masterEnabled = enabled
        linkManager.updateLocalState(deviceActive: phoneState.isUnlocked, masterEnabled: enabled)
        reevaluate()
    }

    func reevaluate() {
        let remote = linkManager.remotePeer
        let decision = DecisionEngine.evaluate(
            masterEnabledLocal: masterEnabled,
            masterEnabledRemote: remote.masterEnabled,
            localDeviceActive: phoneState.isUnlocked,
            remoteDeviceActive: remote.deviceActive,
            linkLive: remote.isLinkLive
        )
        blockDecision = decision
        statusSummary = decisionStatus(decision, remote: remote)
        applyShieldForDecision(decision)
    }

    private func applyShieldForDecision(_ decision: BlockDecision) {
        switch decision {
        case .block:
            guard authManager.isAuthorized else { return }
            // Never shield while the user is inside OneOrOther — otherwise the app
            // blocks itself and appears as a blank/black screen on launch.
            if isAppInForeground {
                if shieldController.isShieldActive {
                    shieldController.removeShield()
                    Log.line("AppCoordinator", "shield removed — OneOrOther is in foreground")
                }
            } else {
                shieldController.applyShield()
            }
        case .clear:
            shieldController.removeShield()
        }
    }

    private func decisionStatus(_ decision: BlockDecision, remote: RemotePeerState) -> String {
        switch decision {
        case .block:
            if isAppInForeground {
                return "BLOCKED — shield applies when you leave this app"
            }
            return "BLOCKED — both devices active"
        case .clear(let reason):
            let link = remote.isLinkLive ? "live" : "uncertain"
            return "Clear — \(reason) [link: \(link)]"
        }
    }
}
