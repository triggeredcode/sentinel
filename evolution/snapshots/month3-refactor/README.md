# Sentinel v0.5 - The Refactor

October 2025 refactored version.

## Changes from v0.1
- Modular Swift architecture
- Menu bar status item
- TLS 1.3 support
- Keychain token storage
- Separate classes for each concern

## Building
```bash
swift build
.build/debug/Sentinel
```

## Architecture
- AppDelegate: UI and coordination
- ScreenshotCapture: Image capture
- NetworkUploader: HTTPS upload
- KeychainManager: Token storage
- PowerManager: Sleep prevention
- Logger: File logging
