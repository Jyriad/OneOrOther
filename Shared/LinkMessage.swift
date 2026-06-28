import Foundation

struct LinkMessage: Codable, Equatable {
    enum Kind: String, Codable {
        case heartbeat
        case state
    }

    let kind: Kind
    let timestamp: Date
    let deviceActive: Bool
    let masterEnabled: Bool
    let deviceName: String

    static func heartbeat(deviceActive: Bool, masterEnabled: Bool, deviceName: String) -> LinkMessage {
        LinkMessage(
            kind: .heartbeat,
            timestamp: Date(),
            deviceActive: deviceActive,
            masterEnabled: masterEnabled,
            deviceName: deviceName
        )
    }

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decode(from data: Data) -> LinkMessage? {
        try? JSONDecoder().decode(LinkMessage.self, from: data)
    }
}

struct RemotePeerState: Equatable {
    var isConnected: Bool
    var lastMessage: LinkMessage?
    var lastReceivedAt: Date?

    var deviceActive: Bool {
        lastMessage?.deviceActive ?? false
    }

    var masterEnabled: Bool {
        lastMessage?.masterEnabled ?? true
    }

    var isHeartbeatFresh: Bool {
        guard let lastReceivedAt else { return false }
        return Date().timeIntervalSince(lastReceivedAt) <= AppConstants.heartbeatStaleThreshold
    }

    var isLinkLive: Bool {
        isConnected && isHeartbeatFresh
    }
}
