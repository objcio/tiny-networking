import XCTest
@testable import tiny_networking

final class tiny_networkingTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(tiny_networking().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
