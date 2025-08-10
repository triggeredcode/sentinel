import Cocoa
import CoreGraphics

let displayID = CGMainDisplayID()
let jpegQuality: CGFloat = 0.85
var captureCount = 0

func captureScreen() -> CGImage? {
    return CGDisplayCreateImage(displayID)
}

func toJPEG(_ image: CGImage) -> Data? {
    let bitmap = NSBitmapImageRep(cgImage: image)
    return bitmap.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality])
}

func doCapture() {
    captureCount += 1
    if let img = captureScreen(), let data = toJPEG(img) {
        let path = "/tmp/sentinel_\(captureCount).jpg"
        try? data.write(to: URL(fileURLWithPath: path))
        print("[\(captureCount)] Captured \(data.count / 1024) KB")
    }
}

// Capture every 10 seconds
print("Starting capture loop (10s interval)...")
let timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
    doCapture()
}

doCapture()  // Initial capture
RunLoop.main.run()
