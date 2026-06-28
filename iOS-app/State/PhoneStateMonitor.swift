import Foundation
import UIKit

@MainActor
final class PhoneStateMonitor: ObservableObject {
    @Published private(set) var isUnlocked: Bool = UIApplication.shared.isProtectedDataAvailable

    private var observers: [NSObjectProtocol] = []

    init() {
        isUnlocked = UIApplication.shared.isProtectedDataAvailable
        print("[PhoneStateMonitor] initial unlocked=\(isUnlocked)")

        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: UIApplication.protectedDataDidBecomeAvailableNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isUnlocked = true
                    print("[PhoneStateMonitor] phone unlocked")
                }
            }
        )
        observers.append(
            center.addObserver(
                forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isUnlocked = false
                    print("[PhoneStateMonitor] phone locked")
                }
            }
        )
        observers.append(
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    let unlocked = UIApplication.shared.isProtectedDataAvailable
                    self?.isUnlocked = unlocked
                    print("[PhoneStateMonitor] became active unlocked=\(unlocked)")
                }
            }
        )
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
