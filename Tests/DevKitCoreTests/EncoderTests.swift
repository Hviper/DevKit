import XCTest
@testable import DevKitCore

final class EncoderTests: XCTestCase {
    func testURLEncodingAndDecoding() {
        let original = "https://example.com/api?query=你好世界&id=123"
        let encoded = URLEncoderTool.encode(original, mode: .component)
        XCTAssertTrue(encoded.contains("%E4%BD%A0%E5%A5%BD%E4%B8%96%E7%95%8C"))

        let (decoded, _) = URLEncoderTool.decode(encoded)
        XCTAssertEqual(decoded, original)
    }

    func testBase64EncodingAndDecoding() {
        let text = "DevKit: 极致轻量开发工具箱"
        let encoded = Base64EncoderTool.encodeText(text)
        let result = Base64EncoderTool.decodeText(encoded)

        switch result {
        case .success(let decoded):
            XCTAssertEqual(decoded, text)
        case .failure(let error):
            XCTFail("Base64 decode failed: \(error)")
        }
    }

    func testJWTDecoding() {
        // Sample standard test JWT token
        let sampleJWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE5OTk5OTk5OTl9.4flK7N8qL_7Xv9"
        let result = JWTDecoderTool.decode(sampleJWT)

        switch result {
        case .success(let info):
            XCTAssertTrue(info.headerJSON.contains("HS256"))
            XCTAssertTrue(info.payloadJSON.contains("John Doe"))
            XCTAssertEqual(info.isExpired, false)
        case .failure(let err):
            XCTFail("JWT decode failed: \(err)")
        }
    }
}
