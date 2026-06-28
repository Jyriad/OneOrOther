import Foundation

enum AppConstants {
    static let appGroupID = "group.com.jyriad.oneorother"
    static let iosBundleID = "com.jyriad.oneorother"
    static let macBundleID = "com.jyriad.oneorother.mac"

    // BLE service + characteristic UUIDs (fixed for pairing)
    static let serviceUUID = "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
    static let stateCharacteristicUUID = "B2C3D4E5-F6A7-8901-BCDE-F12345678901"

    static let heartbeatInterval: TimeInterval = 1.0
    static let heartbeatStaleThreshold: TimeInterval = 5.0

    static let masterEnabledKey = "masterEnabled"
    static let lastRemoteStateKey = "lastRemoteStatePayload"
}
