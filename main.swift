import Cocoa
import CoreGraphics

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var statusMenuItem: NSMenuItem!
    var timer: Timer?
    var captureCount = 0
    let serverURL = URL(string: "http://127.0.0.1:8000/upload")!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "📷"
        
        let menu = NSMenu()
        
        statusMenuItem = NSMenuItem(title: "Captures: 0", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Capture Now!", action: #selector(captureNow), keyEquivalent: "n"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem.menu = menu
        startCapture()
    }
    
    func startCapture() {
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.capture()
        }
        capture()
    }
    
    @objc func captureNow() {
        capture()
    }
    
    func capture() {
        guard let img = CGDisplayCreateImage(CGMainDisplayID()) else { return }
        let bitmap = NSBitmapImageRep(cgImage: img)
        guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else { return }
        
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.uploadTask(with: request, from: data) { [weak self] _, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                DispatchQueue.main.async {
                    self?.captureCount += 1
                    self?.statusMenuItem.title = "Captures: \(self?.captureCount ?? 0)"
                }
            }
        }.resume()
    }
    
    @objc func quit() {
        timer?.invalidate()
        NSApplication.shared.terminate(nil)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
