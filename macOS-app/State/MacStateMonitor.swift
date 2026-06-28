import AppKit
import Combine
import Foundation
import IOKit

@MainActor
final class MacStateMonitor: ObservableObject {
    @Published private(set) var isLidOpen: Bool = true
    @Published private(set) var isScreenAwake: Bool = true

    var isActive: Bool { isLidOpen && isScreenAwake }

    private var observers: [NSObjectProtocol] = []

    init() {
        refreshLidState()
        refreshScreenAwake()
        print("[MacStateMonitor] initial lidOpen=\(isLidOpen) screenAwake=\(isScreenAwake)")

        let workspace = NSWorkspace.shared
        let center = workspace.notificationCenter

        observers.append(center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isScreenAwake = true
                print("[MacStateMonitor] screen awake")
            }
        })
        observers.append(center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isScreenAwake = false
                print("[MacStateMonitor] screen asleep")
            }
        })

        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isScreenAwake = false
                print("[MacStateMonitor] screen locked")
            }
        })
        observers.append(distributed.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isScreenAwake = true
                print("[MacStateMonitor] screen unlocked")
            }
        })

        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshLidState()
            }
        }
    }

    deinit {
        observers.forEach {
            NSWorkspace.shared.notificationCenter.removeObserver($0)
            DistributedNotificationCenter.default().removeObserver($0)
        }
    }

    private func refreshLidState() {
        let open = Self.readLidOpen()
        if open != isLidOpen {
            isLidOpen = open
            print("[MacStateMonitor] lid \(open ? "open" : "closed")")
        }
    }

    private func refreshScreenAwake() {
        isScreenAwake = !NSApp.isHidden
    }

  /// AppleClamshellState: 1 = closed, 0 = open. Non-clamshell Macs return open.
    private static func readLidOpen() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return true }
        defer { IOObjectRelease(service) }

        if let value = IORegistryEntryCreateCFProperty(
            service,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Int {
            return value == 0
        }
        return true
    }
}
