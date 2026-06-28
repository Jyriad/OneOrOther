import Foundation

enum BlockDecision: Equatable {
    case block
    case clear(reason: String)
}

struct DecisionEngine {
  /// Returns `.block` only when we are certain both devices are active and the link is live.
  static func evaluate(
    masterEnabledLocal: Bool,
    masterEnabledRemote: Bool,
    localDeviceActive: Bool,
    remoteDeviceActive: Bool,
    linkLive: Bool
  ) -> BlockDecision {
    guard masterEnabledLocal else {
      return .clear(reason: "Master switch off on this device")
    }
    guard masterEnabledRemote else {
      return .clear(reason: "Master switch off on paired device")
    }
    guard linkLive else {
      return .clear(reason: "Bluetooth link uncertain")
    }
    guard localDeviceActive else {
      return .clear(reason: "This device not active")
    }
    guard remoteDeviceActive else {
      return .clear(reason: "Paired device not active")
    }
    return .block
  }
}
