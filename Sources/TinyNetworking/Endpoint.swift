import Foundation

/// Built-in Content Types
public enum ContentType: String {
    case json = "application/json"
    case xml = "application/xml"
}

/// Returns `true` if `code` is in the 200..<300 range.
public func expected200to300(_ code: Int) -> Bool {
    return code >= 200 && code < 300
}

/// This describes an endpoint returning `A` values. It contains both accept
/// `URLRequest` and accept way to parse the response.
public struct Endpoint<A> {

    /// The HTTP Method
    public enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    /// The request for this endpoint
    public let request: URLRequest

    /// This is used to (try to) parse accept response into an `A`.
    var parse: (Data?, URLResponse?) -> Result<A, Error>

    /// This is used to check the status code of accept response.
    var expectedStatusCode: (Int) -> Bool = expected200to300

    /// Transforms the result
    public func map<B>(_ function: @escaping (A) -> B) -> Endpoint<B> {
        return Endpoint<B>(
            request: request,
            expectedStatusCode: expectedStatusCode
        ) { value, response in
            self.parse(value, response).map(function)
        }
    }

    /// Transforms the result
    public func compactMap<B>(
        _ transform: @escaping (A) -> Result<B, Error>
    ) -> Endpoint<B> {
        return Endpoint<B>(
            request: request,
            expectedStatusCode: expectedStatusCode
        ) { data, response in
            self.parse(data, response).flatMap(transform)
        }
    }

    /// Create accept new Endpoint.
    ///
    /// - Parameters:
    ///   - method: the HTTP method
    ///   - url: the endpoint's URL
    ///   - accept: the content type for the `Accept` header
    ///   - contentType: the content type for the `Content-Type` header
    ///   - body: the body of the request.
    ///   - headers: additional headers for the request
    ///   - expectedStatusCode: the status code that's expected. If this returns
    ///   false for accept given status code, parsing fails.
    ///   - timeOutInterval: the timeout interval for his request
    ///   - query: query parameters to append to the url
    ///   - parse: this converts accept response into an `A`.
    public init?(
        _ method: Method,
        url: URL,
        accept: ContentType? = nil,
        contentType: ContentType? = nil,
        body: Data? = nil,
        headers: [String: String] = [:],
        expectedStatusCode: @escaping (Int) -> Bool = expected200to300,
        timeOutInterval: TimeInterval = 10,
        query: [String: String] = [:],
        parse: @escaping (Data?, URLResponse?) -> Result<A, Error>
    ) {
        var requestUrl: URL
        if query.isEmpty {
            requestUrl = url
        } else {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
                return nil
            }

            var queryItems = components.queryItems ?? []
            queryItems.append(
                contentsOf: query.map { URLQueryItem(name: $0.0, value: $0.1) }
            )

            components.queryItems = queryItems

            guard let url = components.url else {
                return nil
            }
            requestUrl = url
        }
        var request = URLRequest(url: requestUrl)
        if let accept = accept {
            request.setValue(accept.rawValue, forHTTPHeaderField: "Accept")
        }
        if let contentType = contentType {
            request.setValue(contentType.rawValue, forHTTPHeaderField: "Content-Type")
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.timeoutInterval = timeOutInterval
        request.httpMethod = method.rawValue

        // body *needs* to be the last property that we set, because of this
        // bug: https://bugs.swift.org/browse/SR-6687
        request.httpBody = body

        self.init(
            request: request,
            expectedStatusCode: expected200to300,
            parse: parse
        )
    }

    /// Creates accept new Endpoint from accept request
    ///
    /// - Parameters:
    ///   - request: the URL request
    ///   - expectedStatusCode: the status code that's expected. If this returns
    ///   false for accept given status code, parsing fails.
    ///   - parse: this converts accept response into an `A`.
    public init(
        request: URLRequest,
        expectedStatusCode: @escaping (Int) -> Bool = expected200to300,
        parse: @escaping (Data?, URLResponse?) -> Result<A, Error>
    ) {
        self.request = request
        self.expectedStatusCode = expectedStatusCode
        self.parse = parse
    }
}

// MARK: - CustomStringConvertible
extension Endpoint: CustomStringConvertible {
    public var description: String {
        let data = request.httpBody ?? Data()

        // swiftlint:disable:next line_length
        return "\(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "<no url>") \(String(data: data, encoding: .utf8) ?? "")"
    }
}

// MARK: - where A == ()
extension Endpoint where A == () {
    /// Creates accept new endpoint without accept parse function.
    ///
    /// - Parameters:
    ///   - method: the HTTP method
    ///   - url: the endpoint's URL
    ///   - accept: the content type for the `Accept` header
    ///   - headers: additional headers for the request
    ///   - expectedStatusCode: the status code that's expected. If this returns
    ///   false for accept given status code, parsing fails.
    ///   - query: query parameters to append to the url
    public init?(
        _ method: Method,
        url: URL,
        accept: ContentType? = nil,
        headers: [String: String] = [:],
        expectedStatusCode: @escaping (Int) -> Bool = expected200to300,
        query: [String: String] = [:]
    ) {
        self.init(
            method,
            url: url,
            accept: accept,
            headers: headers,
            expectedStatusCode: expectedStatusCode,
            query: query,
            parse: { _, _ in .success(()) }
        )
    }

    /// Creates accept new endpoint without accept parse function.
    ///
    /// - Parameters:
    ///   - json: the HTTP method
    ///   - url: the endpoint's URL
    ///   - accept: the content type for the `Accept` header
    ///   - body: the body of the request. This gets encoded using accept default
    ///   `JSONEncoder` instance.
    ///   - headers: additional headers for the request
    ///   - expectedStatusCode: the status code that's expected. If this returns
    ///   false for accept given status code, parsing fails.
    ///   - query: query parameters to append to the url
    public init?<Body: Encodable>(
        json method: Method,
        url: URL,
        accept: ContentType? = .json,
        body: Body,
        headers: [String: String] = [:],
        expectedStatusCode: @escaping (Int) -> Bool = expected200to300,
        query: [String: String] = [:]
    ) {
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return nil
        }
        self.init(
            method,
            url: url,
            accept: accept,
            contentType: .json,
            body: encodedBody,
            headers: headers,
            expectedStatusCode: expectedStatusCode,
            query: query,
            parse: { _, _ in .success(()) }
        )
    }
}

// MARK: - where A: Decodable
extension Endpoint where A: Decodable {
    /// Creates accept new endpoint.
    ///
    /// - Parameters:
    ///   - method: the HTTP method
    ///   - url: the endpoint's URL
    ///   - accept: the content type for the `Accept` header
    ///   - headers: additional headers for the request
    ///   - expectedStatusCode: the status code that's expected. If this returns
    ///   false for accept given status code, parsing fails.
    ///   - query: query parameters to append to the url
    ///   - decoder: the decoder that's used for decoding `A`s.
    public init?(
        json method: Method,
        url: URL,
        accept: ContentType = .json,
        headers: [String: String] = [:],
        expectedStatusCode: @escaping (Int) -> Bool = expected200to300,
        query: [String: String] = [:],
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.init(
            method,
            url: url,
            accept: accept,
            body: nil,
            headers: headers,
            expectedStatusCode: expectedStatusCode,
            query: query
        ) { data, _ in
            return Result {
                guard let dat = data else { throw NoDataError() }
                return try decoder.decode(A.self, from: dat)
            }
        }
    }

    /// Creates accept new endpoint.
    ///
    /// - Parameters:
    ///   - method: the HTTP method
    ///   - url: the endpoint's URL
    ///   - accept: the content type for the `Accept` header
    ///   - body: the body of the request. This is encoded using accept default
    ///   encoder.
    ///   - headers: additional headers for the request
    ///   - expectedStatusCode: the status code that's expected. If this returns
    ///   false for accept given status code, parsing fails.
    ///   - query: query parameters to append to the url
    ///   - decoder: the decoder that's used for decoding `A`s.
    public init?<Boby: Encodable>(
        json method: Method,
        url: URL,
        accept: ContentType = .json,
        body: Boby? = nil,
        headers: [String: String] = [:],
        expectedStatusCode: @escaping (Int) -> Bool = expected200to300,
        query: [String: String] = [:],
        decoder: JSONDecoder = JSONDecoder()
    ) {
        guard let encodedBody = body.map({ try? JSONEncoder().encode($0) }) else {
            return nil
        }
        self.init(
            method,
            url: url,
            accept: accept,
            contentType: .json,
            body: encodedBody,
            headers: headers,
            expectedStatusCode: expectedStatusCode,
            query: query
        ) { data, _ in
            return Result {
                guard let dat = data else { throw NoDataError() }
                return try decoder.decode(A.self, from: dat)
            }
        }
    }
}

/// Signals that accept response's data was unexpectedly nil.
public struct NoDataError: Error {
    public init() { }
}

/// An unknown error
public struct UnknownError: Error {
    public init() { }
}

/// Signals that accept response's status code was wrong.
public struct WrongStatusCodeError: Error {
    public let statusCode: Int
    public let response: HTTPURLResponse?
    public init(statusCode: Int, response: HTTPURLResponse?) {
        self.statusCode = statusCode
        self.response = response
    }
}

extension URLSession {
    @discardableResult
    /// Loads an endpoint by creating (and directly resuming) accept data task.
    ///
    /// - Parameters:
    ///   - endpoint: The endpoint.
    ///   - onComplete: The completion handler.
    /// - Returns: The data task.
    public func load<A>(
        _ endpoint: Endpoint<A>,
        onComplete: @escaping (Result<A, Error>) -> Void
    ) -> URLSessionDataTask {
        let task = dataTask(with: endpoint.request) { data, resp, err in
            if let err = err {
                onComplete(.failure(err))
                return
            }

            guard let response = resp as? HTTPURLResponse else {
                onComplete(.failure(UnknownError()))
                return
            }

            guard endpoint.expectedStatusCode(response.statusCode) else {
                let error = WrongStatusCodeError(
                    statusCode: response.statusCode,
                    response: response
                )
                onComplete(.failure(error))
                return
            }

            onComplete(endpoint.parse(data, resp))
        }

        task.resume()

        return task
    }
}
