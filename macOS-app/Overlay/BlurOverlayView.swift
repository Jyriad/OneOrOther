import SwiftUI

struct BlurOverlayView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("LAPTOP PAUSED")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text("Phone is active. Lock your phone or close this overlay by locking your phone.")
                    .font(.system(.body, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)
                Text("Enforcement is active on both devices.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.0))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4))
    }
}
