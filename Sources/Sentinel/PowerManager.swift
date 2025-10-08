import Foundation
import IOKit.pwr_mgt

/// Manages power assertions to prevent sleep during operations
final class PowerManager {
    static let shared = PowerManager()
    
    private var assertionID: IOPMAssertionID = 0
    private var isActive = false
    
    private init() {}
    
    @discardableResult
    func preventSleep(reason: String = "Sentinel capture in progress") -> Bool {
        guard !isActive else { return true }
        
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        
        isActive = result == kIOReturnSuccess
        if isActive {
            Logger.shared.log("Power assertion acquired", level: .debug)
        }
        return isActive
    }
    
    @discardableResult
    func allowSleep() -> Bool {
        guard isActive else { return true }
        
        let result = IOPMAssertionRelease(assertionID)
        isActive = result != kIOReturnSuccess
        
        if !isActive {
            Logger.shared.log("Power assertion released", level: .debug)
        }
        return !isActive
    }
    
    deinit {
        if isActive {
            IOPMAssertionRelease(assertionID)
        }
    }
}
