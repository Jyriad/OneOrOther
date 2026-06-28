import Combine
import CoreBluetooth
import Foundation
import UIKit

@MainActor
final class PhoneLinkManager: NSObject, ObservableObject {
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var remotePeer = RemotePeerState(isConnected: false)
    @Published private(set) var statusText = "Bluetooth waiting to start…"

    var onRemoteStateUpdated: (() -> Void)?

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var pendingRestorePeripheral: CBPeripheral?
    private var stateCharacteristic: CBCharacteristic?
    private var staleCheckTimer: Timer?
    private var isStarted = false

    private let restoreID = "com.jyriad.oneorother.phone.central"

    override init() {
        super.init()
        Log.boot("PhoneLinkManager created (BLE not started yet)")
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        statusText = "Bluetooth initializing…"
        Log.boot("PhoneLinkManager starting CBCentralManager")
        central = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [
                CBCentralManagerOptionRestoreIdentifierKey: restoreID,
                CBCentralManagerOptionShowPowerAlertKey: true
            ]
        )
        startStaleCheckTimer()
    }

    func updateLocalState(deviceActive: Bool, masterEnabled: Bool) {
        guard let peripheral, let characteristic = stateCharacteristic else { return }
        guard peripheral.state == .connected else { return }

        let message = LinkMessage.heartbeat(
            deviceActive: deviceActive,
            masterEnabled: masterEnabled,
            deviceName: UIDevice.current.name
        )
        guard let data = message.encoded() else { return }
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    private func startStaleCheckTimer() {
        staleCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.remotePeer.isConnected && !self.remotePeer.isHeartbeatFresh {
                    Log.line("PhoneLinkManager", "heartbeat stale — marking link uncertain")
                    self.statusText = "Link uncertain (stale heartbeat)"
                    self.onRemoteStateUpdated?()
                }
            }
        }
    }

    private func beginScanOrReconnect(central: CBCentralManager) {
        if let pending = pendingRestorePeripheral {
            Log.line("PhoneLinkManager", "reconnecting to restored Mac peripheral")
            peripheral = pending
            pending.delegate = self
            pendingRestorePeripheral = nil
            statusText = pending.state == .connected ? "Connected to Mac" : "Reconnecting to Mac…"
            if pending.state != .connected {
                central.connect(pending, options: nil)
            } else {
                remotePeer.isConnected = true
                pending.discoverServices([serviceUUID()])
            }
            return
        }

        if let peripheral, peripheral.state == .connected || peripheral.state == .connecting {
            statusText = peripheral.state == .connected ? "Connected to Mac" : "Connecting to Mac…"
            return
        }

        statusText = "Scanning for Mac…"
        central.scanForPeripherals(
            withServices: [serviceUUID()],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    private func serviceUUID() -> CBUUID {
        CBUUID(string: AppConstants.serviceUUID)
    }

    private func stateUUID() -> CBUUID {
        CBUUID(string: AppConstants.stateCharacteristicUUID)
    }
}

extension PhoneLinkManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            bluetoothState = central.state
            Log.line("PhoneLinkManager", "central state = \(central.state.rawValue)")
            switch central.state {
            case .poweredOn:
                beginScanOrReconnect(central: central)
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

    nonisolated func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        Log.line("PhoneLinkManager", "state restoration triggered — deferring reconnect until powered on")
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
           let restored = peripherals.first {
            Task { @MainActor in
                self.pendingRestorePeripheral = restored
                restored.delegate = self
                self.statusText = "Restoring Mac connection…"
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover discovered: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            if let existing = self.peripheral,
               existing.identifier != discovered.identifier,
               existing.state == .connected || existing.state == .connecting {
                return
            }

            Log.line("PhoneLinkManager", "discovered Mac peripheral")
            self.peripheral = discovered
            discovered.delegate = self
            statusText = "Connecting to Mac…"
            central.stopScan()
            central.connect(discovered, options: nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            Log.line("PhoneLinkManager", "connected to Mac")
            remotePeer.isConnected = true
            statusText = "Connected to Mac"
            peripheral.discoverServices([serviceUUID()])
            onRemoteStateUpdated?()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            Log.line("PhoneLinkManager", "disconnected from Mac error=\(error?.localizedDescription ?? "none")")
            remotePeer = RemotePeerState(isConnected: false)
            stateCharacteristic = nil
            statusText = "Reconnecting to Mac…"
            if central.state == .poweredOn {
                self.peripheral = peripheral
                peripheral.delegate = self
                central.connect(peripheral, options: nil)
            } else {
                self.pendingRestorePeripheral = peripheral
                self.peripheral = nil
            }
            onRemoteStateUpdated?()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            Log.line("PhoneLinkManager", "failed to connect error=\(error?.localizedDescription ?? "none")")
            statusText = "Connection failed — retrying scan…"
            self.peripheral = nil
            if central.state == .poweredOn {
                central.scanForPeripherals(withServices: [serviceUUID()], options: nil)
            }
        }
    }
}

extension PhoneLinkManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            guard error == nil else {
                Log.line("PhoneLinkManager", "discover services error=\(error!.localizedDescription)")
                return
            }
            guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID() }) else { return }
            peripheral.discoverCharacteristics([stateUUID()], for: service)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            guard error == nil else { return }
            guard let characteristic = service.characteristics?.first(where: { $0.uuid == stateUUID() }) else { return }
            stateCharacteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
            Log.line("PhoneLinkManager", "subscribed to Mac state characteristic")
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, let message = LinkMessage.decode(from: data) else { return }
        Task { @MainActor in
            remotePeer.lastMessage = message
            remotePeer.lastReceivedAt = Date()
            remotePeer.isConnected = true
            statusText = "Mac: \(message.deviceActive ? "active" : "idle")"
            Log.line("PhoneLinkManager", "received \(message.kind.rawValue) macActive=\(message.deviceActive)")
            onRemoteStateUpdated?()
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            Log.line("PhoneLinkManager", "write error=\(error.localizedDescription)")
        }
    }
}
