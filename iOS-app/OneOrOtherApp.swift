import SwiftUI

@main
struct OneOrOtherApp: App {
    @StateObject private var coordinator = AppCoordinator()

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

    let phoneState = PhoneStateMonitor()
    let linkManager = PhoneLinkManager()
    let authManager = AuthorizationManager()
    let shieldController = ShieldController()

    private var heartbeatTimer: Timer?
    private var decisionTimer: Timer?

    init() {
        masterEnabled = SharedStateStore.shared.masterEnabled
        linkManager.onRemoteStateUpdated = { [weak self] in
            Task { @MainActor in
                self?.reevaluate()
            }
        }
        startTimers()
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

        switch decision {
        case .block:
            if authManager.isAuthorized {
                shieldController.applyShield()
            }
        case .clear:
            shieldController.removeShield()
        }
    }

    private func decisionStatus(_ decision: BlockDecision, remote: RemotePeerState) -> String {
        switch decision {
        case .block:
            return "BLOCKED — both devices active"
        case .clear(let reason):
            let link = remote.isLinkLive ? "live" : "uncertain"
            return "Clear — \(reason) [link: \(link)]"
        }
    }
}
