# FluxQ Screenshots

This directory contains app screenshots for documentation.

## Captured Screenshots

### iOS
- `ios-tabs.png` - iOS TabView showing all 4 tabs (消息、通讯录、发现、我)

## Screenshots Requiring Manual Capture

Due to macOS Screen Recording permissions and UI interaction requirements, the following screenshots need manual capture:

### macOS
- `macos-main.png` - Main window showing TabView

**How to capture:**
1. Launch FluxQ.app from Xcode or Finder
2. Wait for the app to fully load
3. Press `⌘+Shift+4` then press `Space` to enable window capture mode
4. Click on the FluxQ window
5. Screenshot will be saved to Desktop, rename and move to `docs/images/macos-main.png`

### iOS - Theme Switch
- `ios-theme.png` - Settings showing theme switcher (浅色/深色/系统)

**How to capture:**
1. With iOS simulator running FluxQ
2. Tap the "我" tab at the bottom right
3. The theme switcher should be visible in the settings
4. Run: `xcrun simctl io <DEVICE_UUID> screenshot docs/images/ios-theme.png`
   - Replace `<DEVICE_UUID>` with your simulator's UUID (check with `xcrun simctl list devices`)

### watchOS
- `watch-messages.png` - Watch app message list

**How to capture:**
1. Launch watchOS simulator (paired with iOS simulator)
2. Build and run FluxQ for watchOS target
3. Navigate to message list view
4. Run: `xcrun simctl io <WATCH_UUID> screenshot docs/images/watch-messages.png`

**Note:** watchOS requires a paired iOS simulator and may be complex to set up. Consider creating a placeholder or capturing this later.

## Automation Limitations

Automated screenshot capture via `screencapture` command failed due to:
- macOS Screen Recording permissions required for the terminal/Claude Code
- Window capture (`-w` flag) requires clicking on the window first
- Interactive simulator screenshot works well for iOS but requires the app to be launched

## Simulator Info

iPhone 17 Pro UUID: `375784A3-E069-4977-BB2E-86520DA7E8CD`
Bundle ID: `com.sky-flux.FluxQ`
