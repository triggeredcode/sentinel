import Cocoa
import Network
import Darwin.POSIX.ifaddrs
import Darwin.POSIX.netdb

/// Main application delegate - coordinates all Sentinel components
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Components
    
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    
    private let screenshotCapture = ScreenshotCapture()
    private var httpServer: HTTPServer!
    private var cropSelector: CropSelector?
    
    // MARK: - State
    
    private var captureTimer: Timer?
    private var isCapturing = false
    private var captureCount = 0
    private var lastCaptureTime: Date?
    private var isPaused = false
    
    // MARK: - Configuration
    
    private var captureInterval: TimeInterval = 5.0
    private var maxImages = 5
    private let serverPort: UInt16 = 8000
    private var localIP: String = "127.0.0.1"
    
    // MARK: - Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.shared.log("Sentinel v1.0.0 starting...")
        
        // Get local IP for display
        localIP = getLocalIPAddress() ?? "127.0.0.1"
        Logger.shared.log("Local IP: \(localIP)")
        
        // Setup UI
        setupStatusItem()
        setupMenu()
        
        // Start HTTP server
        httpServer = HTTPServer(port: serverPort)
        guard httpServer.start() else {
            showFatalError(
                title: "Server Error",
                message: "Failed to start web server on port \(serverPort).\n\nAnother application may be using this port."
            )
            return
        }
        
        // Check permissions
        guard checkScreenRecordingPermission() else { return }
        
        // Start monitoring
        NotificationMonitor.shared.startMonitoring()
        
        // Listen for web-triggered captures
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWebCaptureRequest),
            name: .captureRequested,
            object: nil
        )
        
        // Start auto-capture
        startAutoCapture()
        
        Logger.shared.log("Ready at http://\(localIP):\(serverPort)")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.log("Sentinel stopping...")
        stopAutoCapture()
        NotificationMonitor.shared.stopMonitoring()
        httpServer?.stop()
    }
    
    // MARK: - Network
    
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil, 0,
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                    break
                }
            }
        }
        return address
    }
    
    // MARK: - Auto Capture
    
    private func startAutoCapture() {
        Logger.shared.log("Starting auto-capture every \(Int(captureInterval))s")
        performCapture()
        captureTimer = Timer.scheduledTimer(withTimeInterval: captureInterval, repeats: true) { [weak self] _ in
            self?.performCapture()
        }
    }
    
    private func stopAutoCapture() {
        captureTimer?.invalidate()
        captureTimer = nil
    }
    
    @objc private func handleWebCaptureRequest() {
        Logger.shared.log("Capture requested from web viewer")
        performCapture()
    }
    
    private func performCapture() {
        guard !isCapturing else { return }
        isCapturing = true
        
        Task.detached(priority: .userInitiated) { [weak self] in
            defer { 
                Task { @MainActor in
                    self?.isCapturing = false 
                }
            }
            
            guard let self = self,
                  let imageData = self.screenshotCapture.captureMainDisplay() else {
                return
            }
            
            await self.saveScreenshot(imageData)
        }
    }
    
    private func saveScreenshot(_ imageData: Data) async {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storageDir = appSupport.appendingPathComponent("Sentinel")
        
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
        let filename = "screenshot_\(formatter.string(from: Date())).jpg"
        let fileURL = storageDir.appendingPathComponent(filename)
        
        do {
            try imageData.write(to: fileURL)
            
            await MainActor.run {
                captureCount += 1
                lastCaptureTime = Date()
                updateMenuStats()
            }
            
            cleanupOldImages(in: storageDir)
            
        } catch {
            Logger.shared.log("Failed to save: \(error)", level: .error)
        }
    }
    
    private func cleanupOldImages(in directory: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        
        var jpgFiles = files.filter { $0.pathExtension == "jpg" }
        jpgFiles.sort { f1, f2 in
            let d1 = (try? f1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let d2 = (try? f2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return d1 > d2
        }
        
        for file in jpgFiles.dropFirst(maxImages) {
            try? FileManager.default.removeItem(at: file)
        }
    }
    
    // MARK: - UI Setup
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Sentinel")
        }
    }
    
    private func setupMenu() {
        menu = NSMenu()
        
        // URL
        let urlItem = NSMenuItem(title: "📱 http://\(localIP):\(serverPort)", action: #selector(copyURL), keyEquivalent: "c")
        urlItem.tag = 200
        menu.addItem(urlItem)
        
        let hintItem = NSMenuItem(title: "    Click to copy URL", action: nil, keyEquivalent: "")
        hintItem.isEnabled = false
        menu.addItem(hintItem)
        
        menu.addItem(.separator())
        
        // Status
        let statusItem = NSMenuItem(title: "● Capturing every \(Int(captureInterval))s", action: nil, keyEquivalent: "")
        statusItem.tag = 100
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        let cropStatus = NSMenuItem(title: "📐 Full Screen", action: nil, keyEquivalent: "")
        cropStatus.tag = 104
        cropStatus.isEnabled = false
        menu.addItem(cropStatus)
        
        let countItem = NSMenuItem(title: "Screenshots: 0", action: nil, keyEquivalent: "")
        countItem.tag = 101
        countItem.isEnabled = false
        menu.addItem(countItem)
        
        let lastItem = NSMenuItem(title: "Last: Never", action: nil, keyEquivalent: "")
        lastItem.tag = 102
        lastItem.isEnabled = false
        menu.addItem(lastItem)
        
        menu.addItem(.separator())
        
        // Actions
        menu.addItem(NSMenuItem(title: "📸 Capture Now", action: #selector(captureNow), keyEquivalent: "n"))
        
        let pauseItem = NSMenuItem(title: "⏸ Pause Auto-Capture", action: #selector(togglePause), keyEquivalent: "p")
        pauseItem.tag = 103
        menu.addItem(pauseItem)
        
        menu.addItem(.separator())
        
        // Region selection
        menu.addItem(NSMenuItem(title: "✂️ Select Capture Region...", action: #selector(selectCropRegion), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "↩️ Reset to Full Screen", action: #selector(resetCropRegion), keyEquivalent: ""))
        
        menu.addItem(.separator())
        
        // Settings submenu
        let settingsMenu = NSMenu()
        
        let intervalMenu = NSMenu()
        for interval in [2, 3, 5, 10, 15, 30] {
            let item = NSMenuItem(title: "\(interval) seconds", action: #selector(setInterval(_:)), keyEquivalent: "")
            item.tag = interval
            item.state = (interval == Int(captureInterval)) ? .on : .off
            intervalMenu.addItem(item)
        }
        let intervalItem = NSMenuItem(title: "Capture Interval", action: nil, keyEquivalent: "")
        intervalItem.submenu = intervalMenu
        settingsMenu.addItem(intervalItem)
        
        let maxMenu = NSMenu()
        for max in [3, 5, 10, 20, 50] {
            let item = NSMenuItem(title: "\(max) images", action: #selector(setMaxImages(_:)), keyEquivalent: "")
            item.tag = max
            item.state = (max == maxImages) ? .on : .off
            maxMenu.addItem(item)
        }
        let maxItem = NSMenuItem(title: "Keep Images", action: nil, keyEquivalent: "")
        maxItem.submenu = maxMenu
        settingsMenu.addItem(maxItem)
        
        settingsMenu.addItem(.separator())
        settingsMenu.addItem(NSMenuItem(title: "Refresh IP", action: #selector(refreshIP), keyEquivalent: "r"))
        
        let settingsItem = NSMenuItem(title: "⚙️ Settings", action: nil, keyEquivalent: "")
        settingsItem.submenu = settingsMenu
        menu.addItem(settingsItem)
        
        menu.addItem(.separator())
        
        menu.addItem(NSMenuItem(title: "📁 Open Storage Folder", action: #selector(openStorage), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "📋 View Logs", action: #selector(openLogs), keyEquivalent: ""))
        
        menu.addItem(.separator())
        
        menu.addItem(NSMenuItem(title: "Quit Sentinel", action: #selector(quit), keyEquivalent: "q"))
        
        self.statusItem.menu = menu
    }
    
    private func updateMenuStats() {
        if let item = menu.item(withTag: 101) {
            item.title = "Screenshots: \(captureCount)"
        }
        if let item = menu.item(withTag: 102), let time = lastCaptureTime {
            let fmt = DateFormatter()
            fmt.timeStyle = .medium
            item.title = "Last: \(fmt.string(from: time))"
        }
    }
    
    private func updateCropStatus() {
        if let item = menu.item(withTag: 104) {
            if let region = screenshotCapture.cropRegion {
                item.title = "📐 Region: \(Int(region.width))×\(Int(region.height))"
            } else {
                item.title = "📐 Full Screen"
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func copyURL() {
        let url = "http://\(localIP):\(serverPort)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        
        if let item = menu.item(withTag: 200) {
            let original = item.title
            item.title = "✓ Copied!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { item.title = original }
        }
    }
    
    @objc private func refreshIP() {
        localIP = getLocalIPAddress() ?? "127.0.0.1"
        if let item = menu.item(withTag: 200) {
            item.title = "📱 http://\(localIP):\(serverPort)"
        }
        Logger.shared.log("IP refreshed: \(localIP)")
    }
    
    @objc private func captureNow() {
        performCapture()
    }
    
    @objc private func togglePause() {
        isPaused = !isPaused
        
        if isPaused {
            stopAutoCapture()
        } else {
            startAutoCapture()
        }
        
        if let item = menu.item(withTag: 103) {
            item.title = isPaused ? "▶️ Resume Auto-Capture" : "⏸ Pause Auto-Capture"
        }
        if let item = menu.item(withTag: 100) {
            item.title = isPaused ? "○ Paused" : "● Capturing every \(Int(captureInterval))s"
        }
        
        Logger.shared.log(isPaused ? "Auto-capture paused" : "Auto-capture resumed")
    }
    
    @objc private func selectCropRegion() {
        let wasPaused = isPaused
        if !wasPaused { stopAutoCapture() }
        
        cropSelector = CropSelector()
        cropSelector?.selectRegion { [weak self] rect in
            guard let self = self else { return }
            
            if let rect = rect {
                self.screenshotCapture.cropRegion = rect
                Logger.shared.log("Crop region set: \(rect)")
            }
            
            self.updateCropStatus()
            self.cropSelector = nil
            
            if !wasPaused { self.startAutoCapture() }
        }
    }
    
    @objc private func resetCropRegion() {
        screenshotCapture.cropRegion = nil
        updateCropStatus()
        Logger.shared.log("Crop region reset")
    }
    
    @objc private func setInterval(_ sender: NSMenuItem) {
        captureInterval = TimeInterval(sender.tag)
        
        if let settingsItem = menu.item(withTitle: "⚙️ Settings"),
           let settingsMenu = settingsItem.submenu,
           let intervalItem = settingsMenu.item(withTitle: "Capture Interval"),
           let intervalMenu = intervalItem.submenu {
            for item in intervalMenu.items {
                item.state = (item.tag == sender.tag) ? .on : .off
            }
        }
        
        if let item = menu.item(withTag: 100), !isPaused {
            item.title = "● Capturing every \(Int(captureInterval))s"
        }
        
        if !isPaused {
            stopAutoCapture()
            startAutoCapture()
        }
        
        Logger.shared.log("Interval changed to \(Int(captureInterval))s")
    }
    
    @objc private func setMaxImages(_ sender: NSMenuItem) {
        maxImages = sender.tag
        
        if let settingsItem = menu.item(withTitle: "⚙️ Settings"),
           let settingsMenu = settingsItem.submenu,
           let maxItem = settingsMenu.item(withTitle: "Keep Images"),
           let maxMenu = maxItem.submenu {
            for item in maxMenu.items {
                item.state = (item.tag == sender.tag) ? .on : .off
            }
        }
        
        Logger.shared.log("Max images changed to \(maxImages)")
    }
    
    @objc private func openStorage() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storageDir = appSupport.appendingPathComponent("Sentinel")
        NSWorkspace.shared.open(storageDir)
    }
    
    @objc private func openLogs() {
        NSWorkspace.shared.open(Logger.shared.logPath)
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Permissions
    
    private func checkScreenRecordingPermission() -> Bool {
        let testCapture = ScreenshotCapture()
        
        if testCapture.captureMainDisplay() == nil {
            Logger.shared.log("Screen recording permission needed", level: .warn)
            
            let alert = NSAlert()
            alert.messageText = "Screen Recording Permission Required"
            alert.informativeText = """
            Sentinel needs permission to capture your screen.
            
            1. Click "Open Settings"
            2. Enable "Sentinel"
            3. Restart the app
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Quit")
            
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
            
            httpServer?.stop()
            NSApplication.shared.terminate(nil)
            return false
        }
        return true
    }
    
    private func showFatalError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Quit")
        alert.runModal()
        NSApplication.shared.terminate(nil)
    }
}
