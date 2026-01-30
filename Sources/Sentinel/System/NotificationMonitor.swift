import Cocoa

/// Monitors system events for the activity feed
final class NotificationMonitor: @unchecked Sendable {
    static let shared = NotificationMonitor()
    
    struct Event: Codable, Sendable {
        let id: String
        let timestamp: Date
        let type: String
        let title: String
        let body: String
    }
    
    private var events: [Event] = []
    private let maxEvents = 50
    private let lock = NSLock()
    private var clipboardTimer: Timer?
    private var lastClipboardCount = 0
    
    private init() {}
    
    /// Starts monitoring system events
    func startMonitoring() {
        let nc = NSWorkspace.shared.notificationCenter
        
        // App lifecycle
        nc.addObserver(self, selector: #selector(appLaunched),
                      name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(appTerminated),
                      name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        
        // System power
        nc.addObserver(self, selector: #selector(systemWoke),
                      name: NSWorkspace.didWakeNotification, object: nil)
        nc.addObserver(self, selector: #selector(systemSleeping),
                      name: NSWorkspace.willSleepNotification, object: nil)
        
        // Screen lock
        nc.addObserver(self, selector: #selector(screenLocked),
                      name: NSWorkspace.screensDidSleepNotification, object: nil)
        nc.addObserver(self, selector: #selector(screenUnlocked),
                      name: NSWorkspace.screensDidWakeNotification, object: nil)
        
        // Clipboard monitoring
        startClipboardMonitoring()
        
        Logger.shared.log("Activity monitoring started")
    }
    
    /// Stops monitoring
    func stopMonitoring() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        clipboardTimer?.invalidate()
        clipboardTimer = nil
        Logger.shared.log("Activity monitoring stopped")
    }
    
    // MARK: - Clipboard Monitoring
    
    private func startClipboardMonitoring() {
        lastClipboardCount = NSPasteboard.general.changeCount
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    private func checkClipboard() {
        let count = NSPasteboard.general.changeCount
        guard count != lastClipboardCount else { return }
        lastClipboardCount = count
        
        var content = "Unknown"
        if let text = NSPasteboard.general.string(forType: .string) {
            let preview = String(text.prefix(100))
            content = preview.count < text.count ? "\(preview)..." : preview
        } else if NSPasteboard.general.data(forType: .png) != nil ||
                  NSPasteboard.general.data(forType: .tiff) != nil {
            content = "[Image copied]"
        } else if let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            content = urls.map { $0.lastPathComponent }.joined(separator: ", ")
        }
        
        addEvent(type: "clipboard", title: "Clipboard Changed", body: content)
    }
    
    // MARK: - Event Handlers
    
    @objc private func appLaunched(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let name = app.localizedName else { return }
        addEvent(type: "app_launch", title: "App Launched", body: name)
    }
    
    @objc private func appTerminated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let name = app.localizedName else { return }
        addEvent(type: "app_quit", title: "App Quit", body: name)
    }
    
    @objc private func systemWoke(_ notification: Notification) {
        addEvent(type: "system", title: "System Wake", body: "Mac woke from sleep")
    }
    
    @objc private func systemSleeping(_ notification: Notification) {
        addEvent(type: "system", title: "System Sleep", body: "Mac going to sleep")
    }
    
    @objc private func screenLocked(_ notification: Notification) {
        addEvent(type: "security", title: "Screen Locked", body: "Display turned off")
    }
    
    @objc private func screenUnlocked(_ notification: Notification) {
        addEvent(type: "security", title: "Screen Unlocked", body: "Display turned on")
    }
    
    // MARK: - Event Management
    
    private func addEvent(type: String, title: String, body: String) {
        let event = Event(
            id: UUID().uuidString,
            timestamp: Date(),
            type: type,
            title: title,
            body: body
        )
        
        lock.lock()
        events.insert(event, at: 0)
        if events.count > maxEvents {
            events = Array(events.prefix(maxEvents))
        }
        lock.unlock()
    }
    
    /// Returns events as JSON string
    func getEventsJSON() -> String {
        lock.lock()
        let currentEvents = events
        lock.unlock()
        
        let formatter = ISO8601DateFormatter()
        let items = currentEvents.map { event -> [String: Any] in
            [
                "id": event.id,
                "timestamp": formatter.string(from: event.timestamp),
                "type": event.type,
                "title": event.title,
                "body": event.body
            ]
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: items),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
    
    /// Clears all events
    func clearEvents() {
        lock.lock()
        events.removeAll()
        lock.unlock()
    }
}
