import Foundation
import os.log

enum Log {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private static let subsystem = "com.jyriad.oneorother"
    private static let general = Logger(subsystem: subsystem, category: "general")
    private static let boot = Logger(subsystem: subsystem, category: "boot")

    static func line(_ tag: String, _ message: String) {
        let formatted = "\(formatter.string(from: Date())) [\(tag)] \(message)"
        print(formatted)
        general.info("\(formatted, privacy: .public)")
    }

    static func boot(_ message: String) {
        let formatted = "\(formatter.string(from: Date())) [BOOT] \(message)"
        print(formatted)
        boot.info("\(formatted, privacy: .public)")
    }
}
