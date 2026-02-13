# Manual Screenshot Capture Guide

This guide provides step-by-step instructions for capturing the remaining screenshots that couldn't be automated.

## Prerequisites

- FluxQ app successfully built for all platforms
- Xcode installed with simulators configured
- Screen Recording permissions granted (for macOS screenshots)

## Screenshots Status

### ✅ Completed (Automated)
- `docs/images/ios-tabs.png` - iOS TabView (captured via simulator)

### ⏳ Pending (Manual Capture Required)

#### 1. macOS Main Window (`docs/images/macos-main.png`)

**Why manual:** macOS `screencapture` command requires Screen Recording permissions which aren't granted to the terminal by default.

**Steps:**
```bash
# 1. Launch the macOS app
open ~/Library/Developer/Xcode/DerivedData/FluxQ-*/Build/Products/Debug/FluxQ.app

# 2. Wait for app to fully load (2-3 seconds)

# 3. Use macOS screenshot shortcut:
#    Press: ⌘+Shift+4 then Space
#    Cursor changes to camera icon
#    Click on the FluxQ window
#    Screenshot saves to Desktop as "Screen Shot YYYY-MM-DD at HH.MM.SS.png"

# 4. Rename and move to correct location
mv ~/Desktop/Screen\ Shot*.png docs/images/macos-main.png
```

**Alternative method (if you want to use terminal):**
```bash
# Grant Screen Recording permission to Terminal.app in:
# System Settings > Privacy & Security > Screen Recording

# Then run:
open ~/Library/Developer/Xcode/DerivedData/FluxQ-*/Build/Products/Debug/FluxQ.app
sleep 3
screencapture -x -o -w docs/images/macos-main.png
# Click on FluxQ window when prompted
```

#### 2. iOS Theme Switcher (`docs/images/ios-theme.png`)

**Why manual:** Requires user interaction to navigate to the settings tab.

**Steps:**
```bash
# 1. Ensure iOS simulator is running with FluxQ app
DEVICE_UUID="375784A3-E069-4977-BB2E-86520DA7E8CD"

# 2. Verify app is running
xcrun simctl launch "$DEVICE_UUID" "com.sky-flux.FluxQ"

# 3. In the simulator window:
#    - Click the "我" (Me) tab at the bottom right
#    - The settings/profile screen should show theme options

# 4. Capture screenshot
xcrun simctl io "$DEVICE_UUID" screenshot docs/images/ios-theme.png
```

**Expected content:** Settings screen showing theme switcher with options for 浅色/深色/系统 themes.

#### 3. watchOS Messages (`docs/images/watch-messages.png`)

**Why manual:** watchOS requires paired iOS simulator and separate build configuration.

**Status:** OPTIONAL - Can be deferred to later or use a placeholder.

**Steps (if you want to capture):**
```bash
# 1. Find paired watch simulator
WATCH_UUID=$(xcrun simctl list devices available | grep "Apple Watch" | grep -oE '[0-9A-F-]{36}' | head -1)
echo "Watch UUID: $WATCH_UUID"

# 2. Boot watch simulator (requires paired iOS simulator)
xcrun simctl boot "$WATCH_UUID" || true
open -a Simulator

# 3. Build for watchOS (this is complex - may require Xcode GUI)
xcodebuild -project FluxQ.xcodeproj \
           -scheme FluxQWatch \
           -destination "id=$WATCH_UUID" \
           build

# 4. Launch watch app
xcrun simctl launch "$WATCH_UUID" "com.sky-flux.FluxQ.watchkitapp"

# 5. Capture screenshot
xcrun simctl io "$WATCH_UUID" screenshot docs/images/watch-messages.png
```

**Note:** watchOS screenshots are complex. Consider creating a placeholder or deferring to a future task.

## Placeholder Option

If manual capture is too time-consuming, you can create placeholder images:

```bash
# Create a simple placeholder using ImageMagick or similar tool
# Or create a text file explaining screenshots are coming soon
echo "Screenshot coming soon - macOS main window" > docs/images/macos-main-placeholder.txt
```

## After Capturing Screenshots

Once you have the screenshots, update the commit:

```bash
# Add new screenshots
git add docs/images/

# Commit
git commit -m "docs: add remaining app screenshots (macOS, iOS theme, watchOS)"

# Push to remote
git push origin feature/cdba-tasks
```

## Troubleshooting

### macOS Screenshot Permission Denied
- Go to System Settings > Privacy & Security > Screen Recording
- Add Terminal.app or your terminal emulator
- Restart terminal

### iOS Simulator Not Responding
```bash
# Kill and restart simulator
killall Simulator
xcrun simctl shutdown all
xcrun simctl boot "375784A3-E069-4977-BB2E-86520DA7E8CD"
open -a Simulator
```

### watchOS Pairing Issues
- Open Xcode > Window > Devices and Simulators
- Verify iOS and watchOS simulators are properly paired
- Create new paired simulators if needed

## Quick Reference

**Bundle ID:** `com.sky-flux.FluxQ`
**iPhone Simulator:** iPhone 17 Pro (`375784A3-E069-4977-BB2E-86520DA7E8CD`)
**Screenshots Directory:** `/Users/martinadamsdev/workspace/FluxQ/docs/images/`

## Build Verification

Both builds completed successfully:
- ✅ macOS: `** BUILD SUCCEEDED **`
- ✅ iOS: `** BUILD SUCCEEDED **`
- ⏹️ watchOS: Included in iOS build (not separately tested)
