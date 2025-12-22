import XCTest
@testable import Sentinel

final class HTTPServerTests: XCTestCase {
    var server: HTTPServer!
    
    override func setUp() {
        server = HTTPServer(port: 9999)
    }
    
    override func tearDown() {
        server.stop()
    }
    
    func testServerStarts() {
        let started = server.start()
        XCTAssertTrue(started, "Server should start")
    }
    
    func testHealthEndpoint() async throws {
        _ = server.start()
        
        let url = URL(string: "http://127.0.0.1:9999/")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertGreaterThan(data.count, 0)
    }
    
    func testImagesEndpoint() async throws {
        _ = server.start()
        
        let url = URL(string: "http://127.0.0.1:9999/images")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertNotNil(json)
    }
}
