import Foundation

/// Thread-safe file logger
final class Logger: Sendable {
    static let shared = Logger()
    
    let logPath: URL
    private let dateFormatter: ISO8601DateFormatter
    private let queue = DispatchQueue(label: "com.sentinel.logger")
    
    private init() {
        // Log to ~/Library/Logs/sentinel.log
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs")
        
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        
        logPath = logsDir.appendingPathComponent("sentinel.log")
        
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Create file if needed
        if !FileManager.default.fileExists(atPath: logPath.path) {
            FileManager.default.createFile(atPath: logPath.path, contents: nil)
        }
    }
    
    /// Logs a message with timestamp
    func log(_ message: String, level: Level = .info) {
        queue.async { [self] in
            let timestamp = dateFormatter.string(from: Date())
            let line = "[\(timestamp)] [\(level.rawValue)] \(message)\n"
            
            if let data = line.data(using: .utf8),
               let handle = try? FileHandle(forWritingTo: logPath) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
            
            #if DEBUG
            print(line, terminator: "")
            #endif
        }
    }
    
    enum Level: String, Sendable {
        case debug = "DEBUG"
        case info = "INFO"
        case warn = "WARN"
        case error = "ERROR"
    }
}
