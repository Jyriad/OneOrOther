import Combine
import CoreBluetooth
import Foundation
import UIKit

@MainActor
final class PhoneLinkManager: NSObject, ObservableObject {
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var remotePeer = RemotePeerState(isConnected: false)
    @Published private(set) var statusText = "Bluetooth initializing…"

    var onRemoteStateUpdated: (() -> Void)?

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var stateCharacteristic: CBCharacteristic?
    private var heartbeatTimer: Timer?
    private var staleCheckTimer: Timer?

    private let restoreID = "com.jyriad.oneorother.phone.central"

    override init() {
        super.init()
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

    private func startHeartbeat(localActive: Bool, masterEnabled: Bool) {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.heartbeatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateLocalState(deviceActive: localActive, masterEnabled: masterEnabled)
            }
        }
    }

    func bindHeartbeat(to deviceActivePublisher: Published<Bool>.Publisher, masterEnabled: @escaping () -> Bool) {
        heartbeatTimer?.invalidate()
        var lastActive = false
        var cancellable: AnyCancellable?
        cancellable = deviceActivePublisher.sink { [weak self] active in
            lastActive = active
            Task { @MainActor in
                self?.updateLocalState(deviceActive: active, masterEnabled: masterEnabled())
            }
        }
        _ = cancellable
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.heartbeatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateLocalState(deviceActive: lastActive, masterEnabled: masterEnabled())
            }
        }
    }

    private func startStaleCheckTimer() {
        staleCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.remotePeer.isConnected && !self.remotePeer.isHeartbeatFresh {
                    print("[PhoneLinkManager] heartbeat stale — marking link uncertain")
                    self.statusText = "Link uncertain (stale heartbeat)"
                    self.onRemoteStateUpdated?()
                }
            }
        }
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
            print("[PhoneLinkManager] central state = \(central.state.rawValue)")
            switch central.state {
            case .poweredOn:
                statusText = "Scanning for Mac…"
                central.scanForPeripherals(
                    withServices: [serviceUUID()],
                    options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
                )
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
        print("[PhoneLinkManager] state restoration triggered")
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for p in peripherals {
                Task { @MainActor in
                    self.peripheral = p
                    p.delegate = self
                    if p.state == .connected || p.state == .connecting {
                        remotePeer.isConnected = p.state == .connected
                        statusText = "Restoring Mac connection…"
                    }
                    central.connect(p, options: nil)
                }
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            guard self.peripheral == nil else { return }
            print("[PhoneLinkManager] discovered Mac peripheral")
            self.peripheral = peripheral
            peripheral.delegate = self
            statusText = "Connecting to Mac…"
            central.stopScan()
            central.connect(peripheral, options: nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            print("[PhoneLinkManager] connected to Mac")
            remotePeer.isConnected = true
            statusText = "Connected to Mac"
            peripheral.discoverServices([serviceUUID()])
            onRemoteStateUpdated?()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            print("[PhoneLinkManager] disconnected from Mac error=\(error?.localizedDescription ?? "none")")
            remotePeer = RemotePeerState(isConnected: false)
            self.peripheral = nil
            stateCharacteristic = nil
            statusText = "Disconnected — scanning…"
            if central.state == .poweredOn {
                central.scanForPeripherals(withServices: [serviceUUID()], options: nil)
            }
            onRemoteStateUpdated?()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            print("[PhoneLinkManager] failed to connect error=\(error?.localizedDescription ?? "none")")
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
                print("[PhoneLinkManager] discover services error=\(error!)")
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
            print("[PhoneLinkManager] subscribed to Mac state characteristic")
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, let message = LinkMessage.decode(from: data) else { return }
        Task { @MainActor in
            remotePeer.lastMessage = message
            remotePeer.lastReceivedAt = Date()
            remotePeer.isConnected = true
            statusText = "Mac: \(message.deviceActive ? "active" : "idle")"
            print("[PhoneLinkManager] received \(message.kind.rawValue) macActive=\(message.deviceActive)")
            onRemoteStateUpdated?()
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            print("[PhoneLinkManager] write error=\(error.localizedDescription)")
        }
    }
}
