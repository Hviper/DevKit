import XCTest
@testable import DevKitCore

final class GeneratorTests: XCTestCase {
    func testUUIDGeneration() {
        let uuids = UUIDGeneratorTool.generate(count: 10, format: .standard)
        XCTAssertEqual(uuids.count, 10)
        let uniqueSet = Set(uuids)
        XCTAssertEqual(uniqueSet.count, 10)
        XCTAssertEqual(uuids[0].components(separatedBy: "-").count, 5)
    }

    func testTimestampConversion() {
        // 1700000000 = 2023-11-14 22:13:20 UTC
        let result = TimestampConverterTool.convert(timestampString: "1700000000")
        switch result {
        case .success(let conv):
            XCTAssertEqual(conv.seconds, 1700000000)
            XCTAssertTrue(conv.utcFormatted.contains("2023-11-14 22:13:20"))
        case .failure(let err):
            XCTFail("Timestamp conversion failed: \(err)")
        }
    }
}
