@testable import TinyNetworking
import XCTest

final class URLSessionIntegrationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(TinyHTTPStubURLProtocol.self)
    }

    override func tearDown() {
        super.tearDown()
        URLProtocol.unregisterClass(TinyHTTPStubURLProtocol.self)
    }

    func testDataTaskRequest() throws {
        let url = URL(string: "http://www.example.com/example.json")!

        TinyHTTPStubURLProtocol.urls[url] = StubbedResponse(response: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, data: exampleJSON.data(using: .utf8)!)

        let endpoint = Endpoint<[Person]>(json: .get, url: url)
        let expectation = self.expectation(description: "Stubbed network call")

        let task = URLSession.shared.load(endpoint) { result in
            switch result {
            case let .success(payload):
                XCTAssertEqual([Person(name: "Alice"), Person(name: "Bob")], payload)
                expectation.fulfill()
            case let .failure(error):
                XCTFail(String(describing: error))
            }
        }

        task.resume()

        wait(for: [expectation], timeout: 1)
    }
    
    func testWrongStatusCodeErrorIncludesResponseBody() throws {
        let url = URL(string: "http://www.example.com/internal-error.json")!
        let internalErrorResponse = "{ message: \"Some troubleshooting message from the server.\" }".data(using: .utf8)!
        
        TinyHTTPStubURLProtocol.urls[url] = StubbedResponse(response: HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!, data: internalErrorResponse)
        
        let endpoint = Endpoint<[Person]>(json: .get, url: url)
        let expectation = self.expectation(description: "Stubbed network call")
        
        let task = URLSession.shared.load(endpoint) { result in
            switch result {
            case .success:
                XCTFail("Expected an Error in Result.")
            case let .failure(error):
                XCTAssertNotNil(error as? WrongStatusCodeError)
                expectation.fulfill()
            }
        }
        
        task.resume()
        
        wait(for: [expectation], timeout: 1)
    }

    static var allTests = [
        ("testDataTaskRequest", testDataTaskRequest),
        ("testWrongStatusCodeErrorIncludesResponseBody", testWrongStatusCodeErrorIncludesResponseBody)
    ]
}
