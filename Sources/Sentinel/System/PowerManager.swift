import Foundation
import IOKit.pwr_mgt

/// Manages power assertions to prevent idle sleep during operations
final class PowerManager: Sendable {
    static let shared = PowerManager()
    
    private let lock = NSLock()
    private var _assertionID: IOPMAssertionID = IOPMAssertionID(0)
    private var _isActive = false
    
    private init() {}
    
    /// Acquires a power assertion to prevent idle sleep
    @discardableResult
    func preventSleep(reason: String = "Sentinel capture in progress") -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard !_isActive else { return true }
        
        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        
        if result == kIOReturnSuccess {
            _assertionID = assertionID
            _isActive = true
            Logger.shared.log("Power assertion acquired", level: .debug)
            return true
        } else {
            Logger.shared.log("Failed to acquire power assertion: \(result)", level: .error)
            return false
        }
    }
    
    /// Releases the power assertion
    @discardableResult
    func allowSleep() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard _isActive else { return true }
        
        let result = IOPMAssertionRelease(_assertionID)
        
        if result == kIOReturnSuccess {
            _isActive = false
            Logger.shared.log("Power assertion released", level: .debug)
            return true
        } else {
            Logger.shared.log("Failed to release power assertion: \(result)", level: .error)
            return false
        }
    }
    
    /// Checks if sleep prevention is active
    var isPreventingSleep: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isActive
    }
}
