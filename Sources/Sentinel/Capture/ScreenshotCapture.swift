import Cocoa
import CoreGraphics

/// Handles screen capture using CoreGraphics
/// Optimized for minimal memory usage and fast capture
final class ScreenshotCapture: Sendable {
    
    /// JPEG compression quality (0.0 - 1.0)
    /// 0.7 provides good balance between quality and file size (~300-500KB)
    private let jpegQuality: CGFloat
    
    /// Optional crop region (nil = full screen)
    /// Thread-safe via nonisolated(unsafe) - only modified on main thread
    nonisolated(unsafe) var cropRegion: CGRect?
    
    init(quality: CGFloat = 0.7) {
        self.jpegQuality = quality
    }
    
    /// Captures the main display and returns JPEG data
    /// - Returns: JPEG image data, or nil if capture failed
    func captureMainDisplay() -> Data? {
        let displayID = CGMainDisplayID()
        
        let cgImage: CGImage?
        if let region = cropRegion {
            cgImage = CGDisplayCreateImage(displayID, rect: region)
        } else {
            cgImage = CGDisplayCreateImage(displayID)
        }
        
        guard let image = cgImage else {
            Logger.shared.log("Failed to capture display", level: .error)
            return nil
        }
        
        return convertToJPEG(image)
    }
    
    /// Converts a CGImage to JPEG data
    private func convertToJPEG(_ image: CGImage) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        
        guard let jpegData = bitmapRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: jpegQuality]
        ) else {
            Logger.shared.log("Failed to convert to JPEG", level: .error)
            return nil
        }
        
        return jpegData
    }
}
