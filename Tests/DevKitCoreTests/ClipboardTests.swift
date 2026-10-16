import XCTest
@testable import DevKitCore

final class ClipboardTests: XCTestCase {
    func testDetectJWT() {
        let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgN"
        let res = ClipboardDetector.detect(content: jwt)
        XCTAssertEqual(res?.suggestedTool, .jwt)
    }

    func testDetectJSON() {
        let json = "{\"version\": \"1.0.0\", \"active\": true}"
        let res = ClipboardDetector.detect(content: json)
        XCTAssertEqual(res?.suggestedTool, .json)
    }

    func testDetectURL() {
        let url = "https://example.com/search?q=%E6%B5%8B%E8%AF%95"
        let res = ClipboardDetector.detect(content: url)
        XCTAssertEqual(res?.suggestedTool, .url)
    }

    func testDetectTimestamp() {
        let ts = "1700000000"
        let res = ClipboardDetector.detect(content: ts)
        XCTAssertEqual(res?.suggestedTool, .timestamp)
    }

    func testDetectHash() {
        let md5 = "5eb63bbbe01eeed093cb22bb8f5acdc3"
        let res = ClipboardDetector.detect(content: md5)
        XCTAssertEqual(res?.suggestedTool, .hash)
    }
}
