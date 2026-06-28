import AppKit
import SwiftUI

@MainActor
final class BlurOverlayController: ObservableObject {
    @Published private(set) var isVisible = false

    private var windows: [NSWindow] = []

    func show() {
        guard !isVisible else { return }
        isVisible = true
        print("[BlurOverlayController] showing overlay")

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.ignoresMouseEvents = false
            window.hasShadow = false
            window.contentView = NSHostingView(rootView: BlurOverlayView())
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        print("[BlurOverlayController] hiding overlay")
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}
