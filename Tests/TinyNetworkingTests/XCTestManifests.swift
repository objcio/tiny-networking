import XCTest

#if !canImport(ObjectiveC)
    public func allTests() -> [XCTestCaseEntry] {
        return [
            testCase(TinyNetworkingTests.allTests),
            testCase(URLSessionIntegrationTests.allTests),
        ]
    }
#endif
