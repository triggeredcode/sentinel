import IOKit.pwr_mgt

class PowerManager {
    private var assertionID: IOPMAssertionID = 0
    
    func preventSleep() {
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Sentinel capturing" as CFString,
            &assertionID
        )
    }
    
    func allowSleep() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
    }
}
