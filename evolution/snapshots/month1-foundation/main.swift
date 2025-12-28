import Cocoa
import CoreGraphics
import Foundation

// Sentinel v0.1 - The Foundation
// Single-file prototype for screen capture and upload

class ScreenshotAgent {
    let displayID = CGMainDisplayID()
    let serverURL = "http://localhost:5000/upload"
    var timer: Timer?
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            self.captureAndUpload()
        }
        RunLoop.current.run()
    }
    
    func captureAndUpload() {
        guard let image = CGDisplayCreateImage(displayID) else { return }
        
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else { return }
        
        var request = URLRequest(url: URL(string: serverURL)!)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = jpeg
        
        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                print("Upload failed: \(error)")
            }
        }.resume()
    }
}

let agent = ScreenshotAgent()
agent.start()
