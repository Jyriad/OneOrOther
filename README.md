# OneOrOther

Native SwiftUI MVP for macOS + iOS. When the MacBook is open/awake and the iPhone is unlocked at the same time — and Bluetooth confirms both — both devices block.

## Structure

- `Shared/` — shared constants, BLE message format, decision engine
- `iOS-app/` — iPhone app (Screen Time shield)
- `macOS-app/` — Mac menu bar app (full-screen frosted overlay)
- `OneOrOther.xcodeproj` — Xcode project

## Requirements

- Xcode 16+
- Real iPhone (iOS 17+) and MacBook (macOS 14+)
- Apple Developer account
- Bluetooth enabled on both devices

## Open in Xcode

1. Open `OneOrOther.xcodeproj` in Xcode.
2. Select your **Team** under Signing & Capabilities for both targets (`OneOrOther` and `OneOrOtherMac`).
3. Create the App Group `group.com.jyriad.oneorother` in the Apple Developer portal if Xcode prompts you, and enable it on both targets.

## MVP behavior

| Condition | Result |
|-----------|--------|
| Mac lid open + screen awake AND iPhone unlocked AND BLE link live | Both block |
| Phone locks | Blocks clear immediately |
| Mac lid closes | Blocks clear immediately |
| Bluetooth uncertain / disconnected | No block |
| Enforcement toggle OFF (either device) | No block |

## Not in MVP

Payments, accounts, per-app filtering, onboarding, analytics.

## Testing

See [TESTING.md](TESTING.md).
