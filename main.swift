import Cocoa
import CoreGraphics
import Foundation

let displayID = CGMainDisplayID()
let jpegQuality: CGFloat = 0.85
let serverURL = URL(string: "http://127.0.0.1:8000/upload")!
var captureCount = 0
var timer: Timer?  // Store reference to invalidate later

func captureScreen() -> CGImage? {
    return CGDisplayCreateImage(displayID)
}

func toJPEG(_ image: CGImage) -> Data? {
    let bitmap = NSBitmapImageRep(cgImage: image)
    return bitmap.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality])
}

func upload(_ data: Data) {
    var request = URLRequest(url: serverURL)
    request.httpMethod = "POST"
    request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
    
    let task = URLSession.shared.uploadTask(with: request, from: data) { _, response, error in
        if let error = error {
            print("Upload failed: \(error)")
        } else if let http = response as? HTTPURLResponse {
            print("Upload: \(http.statusCode)")
        }
    }
    task.resume()
}

func doCapture() {
    captureCount += 1
    if let img = captureScreen(), let data = toJPEG(img) {
        print("[\(captureCount)] Uploading \(data.count / 1024) KB...")
        upload(data)
    }
}

func cleanup() {
    timer?.invalidate()
    timer = nil
    print("Cleanup complete")
}

// Handle termination
signal(SIGINT) { _ in
    cleanup()
    exit(0)
}

signal(SIGTERM) { _ in
    cleanup()
    exit(0)
}

print("Starting capture + upload (10s interval)...")
timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
    doCapture()
}

doCapture()
RunLoop.main.run()
