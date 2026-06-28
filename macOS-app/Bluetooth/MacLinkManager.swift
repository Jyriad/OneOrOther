import CoreBluetooth
import Foundation

@MainActor
final class MacLinkManager: NSObject, ObservableObject {
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var remotePeer = RemotePeerState(isConnected: false)
    @Published private(set) var statusText = "Bluetooth initializing…"

    var onRemoteStateUpdated: (() -> Void)?

    private var peripheralManager: CBPeripheralManager!
    private var stateCharacteristic: CBMutableCharacteristic?
    private var subscribedCentrals: [CBCentral] = []
    private var heartbeatTimer: Timer?
    private var staleCheckTimer: Timer?

    private var latestLocalActive = false
    private var latestMasterEnabled = true

    private let restoreID = "com.jyriad.oneorother.mac.peripheral"

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(
            delegate: self,
            queue: nil,
            options: [
                CBPeripheralManagerOptionRestoreIdentifierKey: restoreID,
                CBPeripheralManagerOptionShowPowerAlertKey: true
            ]
        )
        startStaleCheckTimer()
    }

    func updateLocalState(deviceActive: Bool, masterEnabled: Bool) {
        latestLocalActive = deviceActive
        latestMasterEnabled = masterEnabled
        broadcastState()
    }

    private func broadcastState() {
        guard peripheralManager.state == .poweredOn else { return }
        guard let characteristic = stateCharacteristic else { return }
        guard !subscribedCentrals.isEmpty else { return }

        let message = LinkMessage.heartbeat(
            deviceActive: latestLocalActive,
            masterEnabled: latestMasterEnabled,
            deviceName: Host.current().localizedName ?? "Mac"
        )
        guard let data = message.encoded() else { return }

        let sent = peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
        if !sent {
            print("[MacLinkManager] BLE queue full, will retry on next heartbeat")
        }
    }

    private func setupService() {
        let characteristic = CBMutableCharacteristic(
            type: CBUUID(string: AppConstants.stateCharacteristicUUID),
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        stateCharacteristic = characteristic

        let service = CBMutableService(type: CBUUID(string: AppConstants.serviceUUID), primary: true)
        service.characteristics = [characteristic]
        peripheralManager.removeAllServices()
        peripheralManager.add(service)

        startAdvertising()
    }

    private func startAdvertising() {
        guard peripheralManager.state == .poweredOn else { return }
        guard !peripheralManager.isAdvertising else { return }
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: AppConstants.serviceUUID)],
            CBAdvertisementDataLocalNameKey: "OneOrOther Mac"
        ])
        statusText = "Advertising for iPhone…"
        Log.line("MacLinkManager", "advertising started")
    }

    private func startHeartbeatTimer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.heartbeatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.broadcastState()
            }
        }
    }

    private func startStaleCheckTimer() {
        staleCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.remotePeer.isConnected && !self.remotePeer.isHeartbeatFresh {
                    print("[MacLinkManager] heartbeat stale — marking link uncertain")
                    self.statusText = "Link uncertain (stale heartbeat)"
                    self.onRemoteStateUpdated?()
                }
            }
        }
    }
}

extension MacLinkManager: CBPeripheralManagerDelegate {
    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        Task { @MainActor in
            bluetoothState = peripheral.state
            Log.line("MacLinkManager", "peripheral state = \(peripheral.state.rawValue)")
            switch peripheral.state {
            case .poweredOn:
                setupService()
                startHeartbeatTimer()
            case .poweredOff:
                statusText = "Bluetooth off"
                remotePeer.isConnected = false
            case .unauthorized:
                statusText = "Bluetooth permission required"
            default:
                statusText = "Bluetooth unavailable"
            }
            onRemoteStateUpdated?()
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {
        print("[MacLinkManager] state restoration triggered")
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        Task { @MainActor in
            if !subscribedCentrals.contains(where: { $0.identifier == central.identifier }) {
                subscribedCentrals.append(central)
            }
            remotePeer.isConnected = true
            statusText = "iPhone connected"
            Log.line("MacLinkManager", "iPhone subscribed")
            broadcastState()
            onRemoteStateUpdated?()
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        Task { @MainActor in
            subscribedCentrals.removeAll { $0.identifier == central.identifier }
            if subscribedCentrals.isEmpty {
                remotePeer = RemotePeerState(isConnected: false)
                statusText = "Waiting for iPhone…"
            }
            Log.line("MacLinkManager", "iPhone unsubscribed — re-advertising")
            startAdvertising()
            onRemoteStateUpdated?()
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard let data = request.value, let message = LinkMessage.decode(from: data) else {
                peripheral.respond(to: request, withResult: .invalidAttributeValueLength)
                continue
            }
            Task { @MainActor in
                remotePeer.lastMessage = message
                remotePeer.lastReceivedAt = Date()
                remotePeer.isConnected = true
                statusText = "iPhone: \(message.deviceActive ? "active" : "idle")"
                print("[MacLinkManager] received \(message.kind.rawValue) phoneActive=\(message.deviceActive)")
                onRemoteStateUpdated?()
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }
}
