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
    private let activityManager = ActivityManager()

    private var heartbeatTimer: Timer?
    private var decisionTimer: Timer?
    private var linkGraceClearTask: Task<Void, Never>?
    private let linkGracePeriod: TimeInterval = 4.0

    init() {
        masterEnabled = SharedStateStore.shared.masterEnabled
        linkManager.onRemoteStateUpdated = { [weak self] in
            Task { @MainActor in
                self?.reevaluate()
            }
        }
        applyActivityState()
        startTimers()
    }

    private func applyActivityState() {
        if masterEnabled {
            activityManager.begin()
        } else {
            activityManager.end()
        }
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
        applyActivityState()
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
            linkGraceClearTask?.cancel()
            linkGraceClearTask = nil
            overlayController.show()
        case .clear:
            handleClearDecision(decision)
        }
    }

    private func handleClearDecision(_ decision: BlockDecision) {
        guard case .clear(let reason) = decision else { return }

        // If the overlay is already visible and only the BLE heartbeat blipped,
        // keep it up briefly. This avoids a distracting unlock/relock flicker
        // during short reconnects without masking true user intent changes.
        if overlayController.isVisible && reason == "Bluetooth link uncertain" {
            guard linkGraceClearTask == nil else { return }
            Log.line("MacAppCoordinator", "holding overlay during Bluetooth grace period")
            linkGraceClearTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(self?.linkGracePeriod ?? 4.0) * 1_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.linkGraceClearTask = nil
                    if case .clear(let currentReason) = self.blockDecision,
                       currentReason == "Bluetooth link uncertain" {
                        Log.line("MacAppCoordinator", "grace period expired — clearing overlay")
                        self.overlayController.hide()
                    }
                }
            }
            return
        }

        linkGraceClearTask?.cancel()
        linkGraceClearTask = nil
        overlayController.hide()
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
