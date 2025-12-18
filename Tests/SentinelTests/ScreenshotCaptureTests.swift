import XCTest
@testable import Sentinel

final class ScreenshotCaptureTests: XCTestCase {
    var capture: ScreenshotCapture!
    
    override func setUp() {
        capture = ScreenshotCapture(quality: 0.7)
    }
    
    func testCaptureMainDisplay() {
        let data = capture.captureMainDisplay()
        XCTAssertNotNil(data, "Should capture main display")
        XCTAssertGreaterThan(data?.count ?? 0, 1000, "JPEG should have substantial size")
    }
    
    func testJPEGHeader() {
        guard let data = capture.captureMainDisplay() else {
            XCTFail("No capture data")
            return
        }
        
        // JPEG magic bytes: FF D8 FF
        XCTAssertEqual(data[0], 0xFF)
        XCTAssertEqual(data[1], 0xD8)
        XCTAssertEqual(data[2], 0xFF)
    }
    
    func testCropRegion() {
        capture.cropRegion = CGRect(x: 0, y: 0, width: 100, height: 100)
        let data = capture.captureMainDisplay()
        XCTAssertNotNil(data)
    }
}
