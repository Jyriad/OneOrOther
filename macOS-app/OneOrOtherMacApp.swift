import SwiftUI

@main
struct OneOrOtherMacApp: App {
    @StateObject private var coordinator = MacAppCoordinator()

    var body: some Scene {
        MenuBarExtra("OneOrOther", systemImage: "scalemass.fill") {
            MenuBarView()
                .environmentObject(coordinator)
                .frame(width: 320)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class MacAppCoordinator: ObservableObject {
    @Published var masterEnabled: Bool
    @Published private(set) var blockDecision: BlockDecision = .clear(reason: "Starting up")
    @Published private(set) var statusSummary = "Initializing…"

    let macState = MacStateMonitor()
    let linkManager = MacLinkManager()
    let overlayController = BlurOverlayController()

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
                    deviceActive: self.macState.isActive,
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
        linkManager.updateLocalState(deviceActive: macState.isActive, masterEnabled: enabled)
        reevaluate()
    }

    func reevaluate() {
        let remote = linkManager.remotePeer
        let decision = DecisionEngine.evaluate(
            masterEnabledLocal: masterEnabled,
            masterEnabledRemote: remote.masterEnabled,
            localDeviceActive: macState.isActive,
            remoteDeviceActive: remote.deviceActive,
            linkLive: remote.isLinkLive
        )
        blockDecision = decision
        statusSummary = decisionStatus(decision, remote: remote)

        switch decision {
        case .block:
            overlayController.show()
        case .clear:
            overlayController.hide()
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
