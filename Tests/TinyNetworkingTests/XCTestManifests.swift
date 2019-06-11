import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(tiny_networkingTests.allTests),
    ]
}
#endif
