import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var capture: ScreenshotCapture!
    var uploader: NetworkUploader!
    var timer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        capture = ScreenshotCapture()
        uploader = NetworkUploader()
        startCapturing()
    }
    
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "📷"
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Capture Now", action: #selector(captureNow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    func startCapturing() {
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            self.captureAndUpload()
        }
    }
    
    func captureAndUpload() {
        guard let jpeg = capture.captureAsJPEG() else { return }
        uploader.upload(jpeg)
    }
    
    @objc func captureNow() { captureAndUpload() }
    @objc func quit() { NSApp.terminate(nil) }
}
