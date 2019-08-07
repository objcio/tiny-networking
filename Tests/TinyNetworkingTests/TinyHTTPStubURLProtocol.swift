import Foundation

struct StubbedResponse {
    let response: HTTPURLResponse
    let data: Data
}

class TinyHTTPStubURLProtocol: URLProtocol {
    static var urls = [URL: StubbedResponse]()

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        return urls.keys.contains(url)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override class func requestIsCacheEquivalent(_: URLRequest, to _: URLRequest) -> Bool {
        return false
    }

    override func startLoading() {
        guard let client = client, let url = request.url, let stub = TinyHTTPStubURLProtocol.urls[url] else {
            fatalError()
        }

        client.urlProtocol(self, didReceive: stub.response, cacheStoragePolicy: .notAllowed)
        client.urlProtocol(self, didLoad: stub.data)
        client.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
