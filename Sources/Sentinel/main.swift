import Cocoa

// ============================================================================
// Sentinel v1.0.0 - Production Ready
// December 2025
//
// A silent guardian for your Mac. Captures your screen and streams it to
// your phone over local Wi-Fi. Perfect for monitoring your laptop when
// working in public spaces.
//
// Features:
// - Menu bar app (invisible in dock)
// - Built-in HTTP server (no Python required)
// - Activity monitoring (app launches, clipboard, system events)
// - Region selection for partial captures
// - Power-efficient design (<25MB RAM)
// ============================================================================

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Run as accessory app - no dock icon
app.setActivationPolicy(.accessory)

// Start the event loop
app.run()
