import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var coordinator: MacAppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            statusCard
            masterToggle
            Button("Quit OneOrOther") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(.caption, design: .monospaced))
        }
        .padding(16)
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onChange(of: coordinator.macState.isActive) { _, _ in
            coordinator.reevaluate()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ONEOROTHER")
                .font(.system(.headline, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text("Mac link")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.0))
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusRow("Mac", coordinator.macState.isActive ? "Active" : "Idle")
            statusRow("Lid", coordinator.macState.isLidOpen ? "Open" : "Closed")
            statusRow("Screen", coordinator.macState.isScreenAwake ? "Awake" : "Asleep")
            statusRow("iPhone", coordinator.linkManager.statusText)
            statusRow("Decision", coordinator.statusSummary)
            if coordinator.overlayController.isVisible {
                Text("Overlay active")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.0))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func statusRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label.uppercased())
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var masterToggle: some View {
        Toggle(isOn: Binding(
            get: { coordinator.masterEnabled },
            set: { coordinator.setMasterEnabled($0) }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Enforcement")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white)
                Text("Off = no blocking")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .tint(Color(red: 1.0, green: 0.35, blue: 0.0))
    }
}

#Preview {
    MenuBarView()
        .environmentObject(MacAppCoordinator())
}
