import Foundation

/// This describes an endpoint that combined mulitple endpoint
public struct CombinedEndpoint<A> {
    fileprivate let endpoint: _CombinedEndpoint<A>
}

extension CombinedEndpoint {
    
    /// Transform Endpoint to CombinedEndpoint
    public init(endpoint: Endpoint<A>) {
        self.endpoint = .single(endpoint)
    }
    
    /// Create an endpoint that combined two endpoint which can be loaded in sequence
    /// - Parameter endpoint: the first endpoint
    /// - Parameter transform: take reponse to generate the next endpoint
    public static func sequence<B>(_ endpoint: Endpoint<A>, transform: @escaping (A) -> Endpoint<B>) -> CombinedEndpoint<B> {
        return endpoint.combined.compactMap(transform)
    }
    
    /// Create an endpoint that combined two endpoint which can be loaded simultaneously
    /// - Parameter lhs: the endpoint
    /// - Parameter rhs: other endpoint
    /// - Parameter combine: combine two response to value `C`
    public static func zipped<B, C>(_ lhs: Endpoint<A>, _ rhs: Endpoint<B>, combine: @escaping (A, B) -> C) -> CombinedEndpoint<C> {
        return lhs.combined.zipWith(rhs.combined, combine)
    }
    
    /// Transforms the result
    public func map<B>(_ transform: @escaping (A) -> B) -> CombinedEndpoint<B> {
        return endpoint.map(transform).wrapped
    }
    
    /// Create an endpoint that can load the original endpoint and take the response to load other endpoint
    /// - Parameter transform: take reponse to generate the next endpoint
    public func compactMap<B>(_ transform: @escaping (A) -> Endpoint<B>) -> CombinedEndpoint<B> {
        return endpoint.flatMap { .single(transform($0)) }.wrapped
    }
    
    /// Create an endpoint that can load the original endpoint and take the response to load other endpoint
    /// - Parameter transform: take reponse to generate the next endpoint
    public func flatMap<B>(_ transform: @escaping (A) -> CombinedEndpoint<B>) -> CombinedEndpoint<B> {
        return endpoint.flatMap { transform($0).endpoint }.wrapped
    }
    
    /// Create an endpoint that can load two endpoint simultaneously
    public func zip<B>(_ other: CombinedEndpoint<B>) -> CombinedEndpoint<(A,B)> {
        return zipWith(other, { ($0, $1) })
    }
    
    /// Create an endpoint that can load two endpoint simultaneously
    public func zipWith<B, C>(_ other: CombinedEndpoint<B>, _ combine: @escaping (A,B) -> C) -> CombinedEndpoint<C> {
        return endpoint.zipWith(other.endpoint, combine).wrapped
    }
}


/// An error wrapper that contains multiple errors
public struct Errors: Error {
    public let errors: [Error]
    public init(errors: [Error]) {
        self.errors = errors.flatMap { error -> [Error] in
            guard let e = error as? Errors else { return [error] }
            return e.errors
        }
    }
}

extension URLSession {
    
    /// Loads an combined endpoint and directly resuming
    /// - Parameter e: The endpoint
    /// - Parameter onComplete: The completion handler.
    public func load<A>(_ e: CombinedEndpoint<A>, onComplete: @escaping (Result<A, Error>) -> ()) {
        load(e.endpoint, onComplete: onComplete)
    }
    
    fileprivate func load<A>(_ e: _CombinedEndpoint<A>, onComplete: @escaping (Result<A, Error>) -> ()) {
        switch e {
        case let .single(endpoint):
            load(endpoint, onComplete: onComplete)
            
        case let .sequence(endpoint, transform):
            load(endpoint) { result in
                switch result {
                case let .success(value):
                    self.load(transform(value), onComplete: onComplete)
                case let .failure(error):
                    onComplete(.failure(error))
                }
            }
            
        case let .zipped(l, r, transform):
            let group = DispatchGroup()
            var resultA: Result<Any, Error>!
            var resultB: Result<Any, Error>!
            group.enter()
            load(l) {
                resultA = $0
                group.leave()
            }
            group.enter()
            load(r) {
                resultB = $0
                group.leave()
            }
            group.notify(queue: .global(), execute: {
                switch zip(resultA, resultB) {
                case let .success(l, r):
                    onComplete(.success(transform(l, r)))
                case let .failure(error):
                    onComplete(.failure(error))
                }
            })
        }
    }
}

// MARK: - Internal Data Type
fileprivate indirect enum _CombinedEndpoint<A> {
    case single(Endpoint<A>)
    case sequence(_CombinedEndpoint<Any>, (Any) -> _CombinedEndpoint<A>)
    case zipped(_CombinedEndpoint<Any>, _CombinedEndpoint<Any>, (Any, Any) -> A)
    
    var asAny: _CombinedEndpoint<Any> {
        switch self {
        case let .single(r): return .single(r.map { $0 })
        case let .sequence(l, transform): return .sequence(l, { x in
            transform(x).asAny
        })
        case let .zipped(l, r, f): return .zipped(l, r, { x, y in
            f(x, y)
        })
        }
    }
    
    var wrapped: CombinedEndpoint<A> {
        CombinedEndpoint(endpoint: self)
    }
    
    func map<B>(_ transform: @escaping (A) -> B) -> _CombinedEndpoint<B> {
        switch self {
        case let .single(r): return .single(r.map(transform))
        case let .sequence(l, f):
            return .sequence(l, { x in
                f(x).map(transform)
            })
        case let .zipped(l, r, f):
            return _CombinedEndpoint<B>.zipped(l, r, { x, y in
                transform(f(x, y))
            })
        }
    }
    
    func flatMap<B>(_ transform: @escaping (A) -> _CombinedEndpoint<B>) -> _CombinedEndpoint<B> {
        return _CombinedEndpoint<B>.sequence(self.asAny, { x in
            transform(x as! A)
        })
    }
    
    func zip<B>(_ other: _CombinedEndpoint<B>) -> _CombinedEndpoint<(A,B)> {
        return zipWith(other, { ($0, $1) })
    }
    
    func zipWith<B, C>(_ other: _CombinedEndpoint<B>, _ combine: @escaping (A,B) -> C) -> _CombinedEndpoint<C> {
        return _CombinedEndpoint<C>.zipped(self.asAny, other.asAny, { x, y in
            combine(x as! A, y as! B)
        })
    }
}

// MARK: - Private Helper
extension Endpoint {
    fileprivate var combined: CombinedEndpoint<A> {
        CombinedEndpoint(endpoint: self)
    }
}

fileprivate func zip<A, B>(_ lhs: Result<A, Error>, _ rhs: Result<B, Error>) -> Result<(A, B), Error> {
    switch (lhs, rhs) {
    case let (.success(l), .success(r)): return .success((l, r))
    case let (.failure(l), .failure(r)): return .failure(Errors(errors: [l, r]))
    case let (.failure(l), _): return .failure(l)
    case let (_, .failure(r)): return .failure(r)
    }
}
