@testable import TinyNetworking
import XCTest

final class CombinedEndpointTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(TinyHTTPStubURLProtocol.self)
    }

    override func tearDown() {
        super.tearDown()
        URLProtocol.unregisterClass(TinyHTTPStubURLProtocol.self)
    }
    
    func testTwoEndpointLoadingInSequence() {
        let url = URL(string: "http://www.example.com/example.json")!
        let person = Endpoint<[Person]>(json: .get, url: url)
        let phone = Endpoint<Phone>.phone(of: Person(name: "Alice"))
        TinyHTTPStubURLProtocol.urls[person.request.url!] = StubbedResponse(response: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, data: exampleJSON.data(using: .utf8)!)
        TinyHTTPStubURLProtocol.urls[phone.request.url!] = StubbedResponse(response: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, data: examplePhoneJSON.data(using: .utf8)!)
        
        let endpoint: CombinedEndpoint<Phone> = CombinedEndpoint(endpoint: person).flatMap { persons in
            let person = persons.first(where: { $0.name == "Alice" })
            return CombinedEndpoint(endpoint: .phone(of: person!))
        }
        
        let expectation = self.expectation(description: #function)
        
        URLSession.shared.load(endpoint) { result in
            switch result {
            case let .success(phone):
                XCTAssertEqual(Phone(phone: "0987654321"), phone)
                expectation.fulfill()
            case let .failure(error):
                XCTFail(String(describing: error))
            }
        }
        wait(for: [expectation], timeout: 1)
    }

    func testTwoEndpointLoadingInParallel() {
        let url = URL(string: "http://www.example.com/example.json")!
        let phone = Endpoint<Phone>.phone(of: Person(name: "Alice"))
        let birth = Endpoint<Birth>.birth(of: Person(name: "Alice"))
        TinyHTTPStubURLProtocol.urls[phone.request.url!] = StubbedResponse(response: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, data: examplePhoneJSON.data(using: .utf8)!)
        TinyHTTPStubURLProtocol.urls[birth.request.url!] = StubbedResponse(response: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, data: exampleBirthJSON.data(using: .utf8)!)
        
        let endpoint = CombinedEndpoint(endpoint: phone).zipWith(CombinedEndpoint(endpoint: birth), Info.init)
        
        let expectation = self.expectation(description: #function)
        
        URLSession.shared.load(endpoint) { result in
            switch result {
            case let .success(info):
                XCTAssertEqual(Info(phone: .init(phone: "0987654321"), birth: .init(birth: "2000-01-01")), info)
                expectation.fulfill()
            case let .failure(error):
                XCTFail(String(describing: error))
            }
        }
        wait(for: [expectation], timeout: 1)
    }
    static var allTests = [
        ("testTwoEndpointLoadingInSequence", testTwoEndpointLoadingInSequence),
        ("testTwoEndpointLoadingInParallel", testTwoEndpointLoadingInParallel),
    ]
}

// TEST DATA
struct Phone: Codable, Equatable {
    var phone: String
}

struct Birth: Codable, Equatable {
    var birth: String
}

struct Info: Equatable {
    var phone: Phone
    var birth: Birth
}

extension Endpoint where A == Phone {
    static func phone(of person: Person) -> Endpoint {
        let url = URL(string: "http://www.example.com/example.json")!
        return Endpoint(json: .get, url: url, query: ["info": "phone", "person": person.name])
    }
}

extension Endpoint where A == Birth {
    static func birth(of person: Person) -> Endpoint {
        let url = URL(string: "http://www.example.com/example.json")!
        return Endpoint(json: .get, url: url, query: ["info": "birth", "person": person.name])
    }
}

let examplePhoneJSON = """
{
    "phone": "0987654321"
}
"""

let exampleBirthJSON = """
{
    "birth": "2000-01-01"
}
"""

