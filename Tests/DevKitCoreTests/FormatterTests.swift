import XCTest
@testable import DevKitCore

final class FormatterTests: XCTestCase {
    func testJSONFormatting() {
        let minified = "{\"b\":2,\"a\":1}"
        let prettyResult = JSONFormatterTool.format(minified, mode: .pretty, indent: .twoSpaces)

        switch prettyResult {
        case .success(let formatted):
            XCTAssertTrue(formatted.contains("\n"))
            XCTAssertTrue(formatted.contains("\"a\" : 1") || formatted.contains("\"a\": 1"))
        case .failure(let err):
            XCTFail("Formatting failed: \(err)")
        }
    }

    func testJSONMinifying() {
        let pretty = "{\n  \"name\": \"DevKit\"\n}"
        let minResult = JSONFormatterTool.format(pretty, mode: .minify)

        switch minResult {
        case .success(let minified):
            XCTAssertFalse(minified.contains("\n"))
            XCTAssertTrue(minified.contains("\"name\":\"DevKit\"") || minified.contains("\"name\": \"DevKit\""))
        case .failure(let err):
            XCTFail("Minifying failed: \(err)")
        }
    }

    func testJSONValidationFailure() {
        let invalid = "{\"key\": valueWithoutQuotes}"
        let valResult = JSONFormatterTool.format(invalid, mode: .validate)

        switch valResult {
        case .success:
            XCTFail("Should have failed parsing invalid JSON")
        case .failure(let err):
            XCTAssertTrue(err.message.contains("语法错误") || err.message.contains("JSON 解析失败"))
        }
    }
}
