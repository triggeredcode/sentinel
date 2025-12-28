import Foundation

class Logger {
    static let shared = Logger()
    private let logURL: URL
    
    init() {
        logURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/sentinel.log")
    }
    
    func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                let handle = try? FileHandle(forWritingTo: logURL)
                handle?.seekToEndOfFile()
                handle?.write(data)
                handle?.closeFile()
            } else {
                try? data.write(to: logURL)
            }
        }
    }
}
