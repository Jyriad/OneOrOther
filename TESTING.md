# OneOrOther MVP — Device Testing Guide

Run these tests on a **real iPhone** and **real MacBook** with Bluetooth on. Keep the **Enforcement** toggle ON unless noted.

## Setup (one time)

1. Open `OneOrOther.xcodeproj` in Xcode.
2. For **OneOrOther** (iOS) and **OneOrOtherMac** (macOS), set your Apple Developer **Team** under Signing & Capabilities.
3. If prompted, create App Group `group.com.jyriad.oneorother` in developer.apple.com and enable it on both targets.
4. Build and run **OneOrOtherMac** on your MacBook.
5. Build and run **OneOrOther** on your iPhone (USB or wireless debugging).
6. On iPhone: tap **Authorize Screen Time** and approve the system prompt.
7. Allow **Bluetooth** on both devices when asked.

## Where to watch status

- **Mac:** menu bar icon → status panel shows Mac state, iPhone link, and decision.
- **iPhone:** main screen shows phone state, Mac link, and decision.
- **Xcode console:** filter for `[PhoneLinkManager]`, `[MacLinkManager]`, `[ShieldController]`, `[BlurOverlayController]`.

## Test cases

### 1. Bluetooth link

1. Open both apps.
2. Mac should show “Advertising” then “iPhone connected”.
3. iPhone should show “Connected to Mac”.
4. **Pass:** both show a live link within ~10 seconds.

### 2. Dual-active block

1. Mac lid open, screen awake, using the Mac.
2. Unlock iPhone.
3. **Pass:** Mac shows frosted full-screen overlay; iPhone shows system Screen Time shield; both status panels say BLOCKED.

### 3. Phone lock clears block

1. While blocked, lock iPhone (side button).
2. **Pass:** Mac overlay disappears within ~1 second; iPhone shield clears.

### 4. Lid close clears block

1. Trigger block again (Mac awake + phone unlocked).
2. Close MacBook lid.
3. **Pass:** overlay clears; iPhone shield clears when Mac reports idle.

### 5. Bluetooth uncertainty (fail safe)

1. With Mac awake and phone unlocked, turn off Bluetooth on **either** device (or move out of range).
2. **Pass:** blocks clear; status shows link uncertain; **no block** while uncertain.

### 6. Master switch (safety)

1. Turn **Enforcement** OFF on Mac or iPhone.
2. Unlock phone while Mac is awake.
3. **Pass:** no overlay, no shield.
4. Turn Enforcement back ON to continue testing.

## Troubleshooting

| Issue | What to try |
|-------|-------------|
| iPhone never connects | Quit and reopen both apps; confirm Bluetooth on; Mac app must run first |
| Screen Time shield never appears | Re-run Authorize Screen Time; check Family Controls entitlement in Signing |
| Mac overlay does not appear | Check menu bar app is running; check Decision line in panel |
| “Link uncertain” constantly | Keep both apps in foreground briefly; check console for stale heartbeat logs |

## Known MVP limits

- If you force-quit either app, blocking stops until reopened.
- iPhone unlock detection in deep background may lag slightly; console logs help diagnose.
- Family Controls distribution approval is required for App Store release; development testing on your devices works with your developer account.
