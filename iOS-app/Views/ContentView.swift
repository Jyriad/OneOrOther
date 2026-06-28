import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                header
                statusCard
                masterToggle
                screenTimeSection
                Spacer()
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Log.boot("ContentView appeared")
            coordinator.start()
        }
        .onChange(of: coordinator.phoneState.isUnlocked) { _, _ in
            coordinator.reevaluate()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ONEOROTHER")
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text("iPhone link")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.0))
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusRow("Phone", coordinator.phoneState.isUnlocked ? "Unlocked" : "Locked")
            statusRow("Mac link", coordinator.linkManager.statusText)
            statusRow("Decision", coordinator.statusSummary)
            if coordinator.shieldController.isShieldActive {
                Text("Shield active")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.0))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func statusRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private var masterToggle: some View {
        Toggle(isOn: Binding(
            get: { coordinator.masterEnabled },
            set: { coordinator.setMasterEnabled($0) }
        )) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Enforcement")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white)
                Text("Off = no blocking on either device")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .tint(Color(red: 1.0, green: 0.35, blue: 0.0))
    }

    private var screenTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SCREEN TIME")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)

            if coordinator.authManager.isAuthorized {
                Text("Authorized")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white)
            } else {
                Button("Authorize Screen Time") {
                    Task { await coordinator.authManager.requestAuthorization() }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 1.0, green: 0.35, blue: 0.0))

                if let error = coordinator.authManager.authorizationError {
                    Text(error)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
}
