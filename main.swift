import Cocoa
import CoreGraphics

// Sentinel v0.0.1 - Basic screen capture
// Just trying to get something working...

let displayID = CGMainDisplayID()

func captureScreen() -> CGImage? {
    return CGDisplayCreateImage(displayID)
}

// Quick test
if let img = captureScreen() {
    print("Captured: \(img.width)x\(img.height)")
} else {
    print("Failed to capture")
}
