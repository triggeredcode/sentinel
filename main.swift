import Cocoa
import CoreGraphics

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    let serverURL = URL(string: "http://127.0.0.1:8000/upload")!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "📷"
        
        // Simple menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Sentinel Active", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        
        // Start capturing
        startCapture()
    }
    
    func startCapture() {
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.capture()
        }
        capture()
    }
    
    func capture() {
        guard let img = CGDisplayCreateImage(CGMainDisplayID()) else { return }
        let bitmap = NSBitmapImageRep(cgImage: img)
        guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else { return }
        
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        URLSession.shared.uploadTask(with: request, from: data) { _, _, _ in }.resume()
    }
    
    @objc func quit() {
        timer?.invalidate()
        NSApplication.shared.terminate(nil)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // No dock icon!
let delegate = AppDelegate()
app.delegate = delegate
app.run()
