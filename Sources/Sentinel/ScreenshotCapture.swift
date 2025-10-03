import Cocoa
import CoreGraphics

/// Handles screen capture operations
final class ScreenshotCapture {
    private let jpegQuality: CGFloat
    var cropRegion: CGRect?
    
    init(quality: CGFloat = 0.8) {
        self.jpegQuality = quality
    }
    
    /// Captures the main display
    func captureMainDisplay() -> Data? {
        let displayID = CGMainDisplayID()
        
        let cgImage: CGImage?
        if let region = cropRegion {
            cgImage = CGDisplayCreateImage(displayID, rect: region)
        } else {
            cgImage = CGDisplayCreateImage(displayID)
        }
        
        guard let image = cgImage else {
            print("[Capture] Failed to capture display")
            return nil
        }
        
        return toJPEG(image)
    }
    
    /// Captures all connected displays
    func captureAllDisplays() -> [Data] {
        var results: [Data] = []
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        
        guard displayCount > 0 else { return results }
        
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displays, &displayCount)
        
        for display in displays {
            if let image = CGDisplayCreateImage(display),
               let data = toJPEG(image) {
                results.append(data)
            }
        }
        
        return results
    }
    
    private func toJPEG(_ image: CGImage) -> Data? {
        let bitmap = NSBitmapImageRep(cgImage: image)
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality])
    }
}
