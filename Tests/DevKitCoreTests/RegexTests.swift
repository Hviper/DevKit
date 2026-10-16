import XCTest
@testable import DevKitCore

final class RegexTests: XCTestCase {
    func testRegexMatching() async {
        let pattern = #"\d+"#
        let text = "Order #12345 total 99 dollars"
        let output = await RegexTesterTool.test(pattern: pattern, text: text)

        XCTAssertEqual(output.totalCount, 2)
        XCTAssertEqual(output.matches.first?.fullMatch, "12345")
        XCTAssertEqual(output.matches.last?.fullMatch, "99")
        XCTAssertFalse(output.isTimeout)
    }

    func testRegexSyntaxError() async {
        let pattern = "[("
        let text = "Hello"
        let output = await RegexTesterTool.test(pattern: pattern, text: text)

        XCTAssertNotNil(output.error)
        XCTAssertTrue(output.error?.contains("语法错误") ?? false)
    }
}
