import Cocoa
import CoreGraphics

let displayID = CGMainDisplayID()
let jpegQuality: CGFloat = 0.85  // hardcoded for now

func captureScreen() -> CGImage? {
    return CGDisplayCreateImage(displayID)
}

func toJPEG(_ image: CGImage) -> Data? {
    let bitmap = NSBitmapImageRep(cgImage: image)
    return bitmap.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality])
}

if let img = captureScreen(), let data = toJPEG(img) {
    print("JPEG size: \(data.count / 1024) KB")
    try? data.write(to: URL(fileURLWithPath: "/tmp/screen.jpg"))
    print("Saved to /tmp/screen.jpg")
}
