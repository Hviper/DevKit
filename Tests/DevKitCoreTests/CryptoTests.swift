import XCTest
@testable import DevKitCore

final class CryptoTests: XCTestCase {
    func testHashCalculations() {
        let input = "hello world"
        let hashes = HashGeneratorTool.computeHash(for: input)

        let md5 = hashes.first(where: { $0.algorithm == .md5 })?.hash
        XCTAssertEqual(md5, "5eb63bbbe01eeed093cb22bb8f5acdc3")

        let sha256 = hashes.first(where: { $0.algorithm == .sha256 })?.hash
        XCTAssertEqual(sha256, "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9")
    }

    func testEmptyStringHash() {
        let hashes = HashGeneratorTool.computeHash(for: "")
        let md5 = hashes.first(where: { $0.algorithm == .md5 })?.hash
        // MD5 of empty string is famously d41d8cd98f00b204e9800998ecf8427e
        XCTAssertEqual(md5, "d41d8cd98f00b204e9800998ecf8427e")
    }
}
