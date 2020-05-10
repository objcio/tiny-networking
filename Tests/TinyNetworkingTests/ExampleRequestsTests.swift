@testable import TinyNetworking
import XCTest

struct ExampleArgs: Codable {
    var name: String
}

struct RequestHeaders: Codable {
    var accept: String

    enum CodingKeys: String, CodingKey {
        case accept = "Accept"
    }
}

struct GetRequestResult: Codable {
    var args: ExampleArgs
    var headers: RequestHeaders
}

struct PostFormRequestResult: Codable {
    var form: ExampleArgs
    var headers: RequestHeaders
}

struct PostJsonRequestResult: Codable {
    var data: String
    var headers: RequestHeaders
}

struct Todo: Codable {
    var id: Int?
    var title: String
}

struct TodosEndpoints {
    let url = URL(string: "https://jsonplaceholder.typicode.com/todos/")!

    func get() -> Endpoint<[Todo]> {
        Endpoint(json: .get, url: url)
    }

    func get(id: Int) -> Endpoint<Todo> {
        Endpoint(json: .get, url: urlFor(id: id))
    }

    func put(todo: Todo) -> Endpoint<Todo> {
        Endpoint(json: .put, url: urlFor(id: todo.id!), body: todo)
    }

    func create(todo: Todo) -> Endpoint<Todo> {
        Endpoint(json: .post, url: url, body: todo)
    }

    func delete(todoId: Int) -> Endpoint<Void> {
        Endpoint(.delete, url: urlFor(id: todoId))
    }

    private func urlFor(id: Int) -> URL {
        URL(string: String(id), relativeTo: url)!
    }
}

/**
 These tests make requests to:
 - https://httpbin.org (which returns the request data as json)
 - https://jsonplaceholder.typicode.com (which provides a fake REST API)
 to see common cases how the Endpoint API might be used in one place and
 to check that TinyNetworking carries out the requests as expected.
 */
final class ExampleRequestsTests: XCTestCase {
    func testGetJson() throws {
        let url = URL(string: "https://httpbin.org/get")!

        let endpoint = Endpoint<GetRequestResult>(json: .get, url: url, query: ["name": "hellö ABC"])

        if let result = request(endpoint) {
            XCTAssertEqual("hellö ABC", result.args.name)
            XCTAssertEqual("application/json", result.headers.accept)
        } else {
            XCTFail("No result")
        }
    }

    func testPostJson() throws {
        let url = URL(string: "https://httpbin.org/post")!

        let endpoint = Endpoint<PostJsonRequestResult>(json: .post, url: url, body: ExampleArgs(name: "hellö ABC"))
        if let result = request(endpoint) {
            // httpbin doesn't return a JSON structure but the sent data as String
            let args = try JSONDecoder().decode(ExampleArgs.self, from: result.data.data(using: .utf8)!)
            XCTAssertEqual("hellö ABC", args.name)
            XCTAssertEqual("application/json", result.headers.accept)
        }
    }

    func testPostForm() throws {
        let url = URL(string: "https://httpbin.org/post")!

        var urlComponents = URLComponents()
        urlComponents.queryItems = [
            URLQueryItem(name: "name", value: "hellö ABC"),
        ]
        let body = urlComponents.url!.query!.data(using: .utf8)!

        var endpoint = Endpoint<PostFormRequestResult>(json: .post, url: url)
        endpoint.request.httpBody = body
        endpoint.request.setValue(ContentType.formUrlEncoded.rawValue, forHTTPHeaderField: "Content-Type")

        if let result = request(endpoint) {
            XCTAssertEqual("hellö ABC", result.form.name)
            XCTAssertEqual("application/json", result.headers.accept)
        }
    }

    func testRestAPITodosGet() {
        if let todos = request(TodosEndpoints().get()) {
            XCTAssert(!todos.isEmpty)
        }
        if let todo = request(TodosEndpoints().get(id: 1)) {
            XCTAssertEqual("delectus aut autem", todo.title)
        }
    }

    func testRestAPITodosPut() {
        if let todo = request(TodosEndpoints().put(todo: Todo(id: 1, title: "Hello"))) {
            XCTAssertEqual("Hello", todo.title)
        }
    }

    func testRestAPITodosPost() {
        if let todo = request(TodosEndpoints().create(todo: Todo(title: "Hello"))) {
            XCTAssertEqual("Hello", todo.title)
        }
    }

    func testRestAPITodosDelete() {
        request(TodosEndpoints().delete(todoId: 1))
    }

    private func request<Payload>(_ endpoint: Endpoint<Payload>) -> Payload? {
        let expectation = self.expectation(description: "Request result")

        var payload: Payload?
        let task = URLSession.shared.load(endpoint) { result in
            switch result {
            case let .success(resultPayload):
                payload = resultPayload
            case let .failure(error):
                XCTFail(String(describing: error))
            }
            expectation.fulfill()
        }

        task.resume()
        wait(for: [expectation], timeout: 30)
        return payload
    }
}
