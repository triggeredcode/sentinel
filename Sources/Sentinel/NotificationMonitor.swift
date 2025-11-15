import Cocoa

/// Monitors system events for the activity feed
final class NotificationMonitor {
    static let shared = NotificationMonitor()
    
    struct Event: Codable {
        let id: String
        let timestamp: Date
        let type: String
        let title: String
        let body: String
    }
    
    private var events: [Event] = []
    private let maxEvents = 50
    
    private init() {}
    
    func startMonitoring() {
        let nc = NSWorkspace.shared.notificationCenter
        
        nc.addObserver(self, selector: #selector(appLaunched),
                      name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(appTerminated),
                      name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        
        Logger.shared.log("Notification monitoring started")
    }
    
    func stopMonitoring() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
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
    
    private func addEvent(type: String, title: String, body: String) {
        let event = Event(id: UUID().uuidString, timestamp: Date(), type: type, title: title, body: body)
        events.insert(event, at: 0)
        if events.count > maxEvents { events = Array(events.prefix(maxEvents)) }
    }
    
    func getEventsJSON() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(events) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
    
    func clearEvents() { events.removeAll() }
}

extension NotificationMonitor {
    private static var clipboardTimer: Timer?
    private static var lastClipboardCount = 0
    
    func startClipboardMonitoring() {
        Self.lastClipboardCount = NSPasteboard.general.changeCount
        Self.clipboardTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    private func checkClipboard() {
        let count = NSPasteboard.general.changeCount
        guard count != Self.lastClipboardCount else { return }
        Self.lastClipboardCount = count
        
        var content = "Unknown"
        if let text = NSPasteboard.general.string(forType: .string) {
            content = String(text.prefix(100)) + (text.count > 100 ? "..." : "")
        } else if NSPasteboard.general.data(forType: .png) != nil {
            content = "[Image]"
        }
        
        addEvent(type: "clipboard", title: "Clipboard Changed", body: content)
    }
}
