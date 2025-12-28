import Cocoa
import CoreGraphics

class ScreenshotCapture {
    private let displayID = CGMainDisplayID()
    var jpegQuality: CGFloat = 0.8
    
    func capture() -> CGImage? {
        CGDisplayCreateImage(displayID)
    }
    
    func captureAsJPEG() -> Data? {
        guard let image = capture() else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: image)
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality])
    }
}
