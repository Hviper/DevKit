import XCTest
@testable import DevKitCore

final class DiffTests: XCTestCase {
    func testIdenticalText() async {
        let diff = MyersDiff()
        let text = "Line 1\nLine 2\nLine 3"
        let result = await diff.diff(oldText: text, newText: text)
        XCTAssertTrue(result.isIdentical)
        XCTAssertEqual(result.additions, 0)
        XCTAssertEqual(result.deletions, 0)
        XCTAssertEqual(result.sideBySideRows.count, 3)
    }

    func testSimpleAdditionsAndDeletions() async {
        let diff = MyersDiff()
        let old = "Apple\nBanana\nOrange"
        let new = "Apple\nCherry\nOrange\nPear"

        let result = await diff.diff(oldText: old, newText: new)
        XCTAssertFalse(result.isIdentical)
        XCTAssertGreaterThan(result.additions, 0)
        XCTAssertGreaterThan(result.deletions, 0)
    }

    func testIgnoreWhitespace() async {
        let diff = MyersDiff()
        let old = "  let a = 1;  "
        let new = "let a = 1;"

        let strictResult = await diff.diff(oldText: old, newText: new, ignoreWhitespace: false)
        XCTAssertFalse(strictResult.isIdentical)

        let ignoreResult = await diff.diff(oldText: old, newText: new, ignoreWhitespace: true)
        XCTAssertTrue(ignoreResult.isIdentical)
    }

    func testEmptyInputs() async {
        let diff = MyersDiff()
        let emptyToText = await diff.diff(oldText: "", newText: "Hello")
        XCTAssertEqual(emptyToText.additions, 1)

        let textToEmpty = await diff.diff(oldText: "Hello", newText: "")
        XCTAssertEqual(textToEmpty.deletions, 1)
    }
}
