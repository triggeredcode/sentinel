# Changelog

All notable changes to Sentinel are documented here.

## [1.0.0] - 2025-12-28

### Added
- Production-ready release
- Comprehensive test suite (80% coverage)
- Full documentation

### Changed
- JPEG quality reduced to 0.7 for smaller files
- Memory limit enforced at 25MB via launchd

### Security
- Constant-time token comparison
- Input validation on all HTTP routes
- Directory traversal protection

## [0.9.0] - 2025-11-28

### Added
- NotificationMonitor for activity tracking
- App launch/quit monitoring
- Clipboard change detection
- System sleep/wake events
- Settings submenu (interval, max images)
- launchd plist for auto-start

### Changed
- Viewer improvements (pinch-zoom, rotation)

## [0.5.0] - 2025-10-30

### Added
- Built-in HTTPServer (Network.framework)
- Embedded HTML viewer (no Python dependency)
- CropSelector for region capture
- Modular architecture

### Removed
- Python Flask server dependency
- External viewer.html file

### Changed
- Split into separate Swift files
- Logger, PowerManager, ScreenshotCapture extracted

## [0.2.0] - 2025-09-28

### Added
- Menu bar status item
- Keychain token storage
- TLS 1.3 support
- Self-signed certificate generation
- NetworkUploader class

### Security
- X-Auth-Token header validation
- HTTPS-only communication

## [0.1.0] - 2025-08-31

### Added
- Initial prototype
- Basic screen capture (CGDisplayCreateImage)
- JPEG conversion
- Timer-based auto-capture
- Simple Flask server for receiving uploads
- Basic HTML viewer
