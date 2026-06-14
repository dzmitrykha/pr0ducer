# Activity Tracker (watchOS)

A motivation-focused activity tracker for Apple Watch. Tap the complication to start/stop a focused work session; the app shows a scrollable history of day cards with a 0–24h timeline.

See [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for the full product spec and phased build plan.

## Requirements

- Xcode 26+ with watchOS 26 SDK
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Build

```bash
# SPM packages (fast inner loop)
cd Packages/ActivityTracker && swift build && swift test

# Regenerate Xcode project after changing App/ target files
cd App && xcodegen generate

# Build app + widget for the watch simulator
xcodebuild \
  -project App/ActivityTracker.xcodeproj \
  -scheme ActivityTracker \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -scmProvider system \
  build
```

Adjust the simulator name to one available via `xcrun simctl list devices`.

On first build, Xcode may require trusting SPM macro plugins (TCA, Dependencies, StructuredQueries). If `xcodebuild` fails with macro fingerprint errors, run once in Xcode or set:

```bash
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
```
