import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// A fluent builder pattern implementation for constructing URLRequests.
/// Supports method chaining for adding headers, query parameters, body data etc.
///
/// Example:
/// ```swift
/// let request = URLRequestBuilder()
///     .setMethod(.post)
///     .setHost("api.example.com")
///     .addHeader(.contentType(.json))
///     .build()
/// ```
public class URLRequestBuilder {

    /// The components for the query string
    var components: URLComponents

    /// The http Method
    var method: Method = .get

    /// The http body. Used for post, put, patch, and delete.
    var body: Data?

    /// The Http headers
    var headers: [String: String] = [:]

    /// The service type
    var serviceType: URLRequest.NetworkServiceType = .default

    /// Initializer
    public init() {
        components = URLComponents()
        components.scheme = Scheme.https.rawValue
        _ = addHeader("Accept", value: MimeType.any.rawValue)
    }

    /// Initializer
    /// - parameter string: The URL string to use as the basis for the request
    public init?(string: String) {
        guard let components = URLComponents(string: string) else {
            return nil
        }
        self.components = components
        _ = addHeader(HttpHeader.accept(.any))
    }

    /// Initializer
    /// - parameter url: The URL to use as the basis for the request
    public init?(url: URL) {
        guard !url.isFileURL, let components = URLComponents(string: url.absoluteString) else {
            return nil
        }
        self.components = components
        _ = addHeader(HttpHeader.accept(.any))
    }

    /// Initializer
    /// - parameter baseURL: The URL to use as the basis for the request
    /// - parameter path: The Base Path
    public init?(baseURL: URL, path: String) {
        guard !baseURL.isFileURL, let components = URLComponents(string: baseURL.absoluteString) else {
            return nil
        }
        self.components = components
        _ = appendPath(path)
        _ = addHeader(HttpHeader.accept(.any))
    }

    /// Build Request
    /// - returns: The Newly URL Requests
    public func build() -> URLRequest? {
        guard let url = components.url else {
            return nil
        }

        var request = URLRequest(url: url)
        request.networkServiceType = serviceType
        request.httpMethod = method.rawValue
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        #if DEBUG
            if method == .get {
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            }
        #endif

        if let body {
            switch method {
                case .put,
                     .patch,
                     .delete,
                     .post:
                    request.httpBody = body
                default:
                    break
            }
        }

        return request
    }
}

// MARK: - URL
public extension URLRequestBuilder {

    /// Set the network service type
    /// - parameter type: The network service type
    /// - returns: `self`
    func setServiceType(_ type: URLRequest.NetworkServiceType) -> Self {
        serviceType = type
        return self
    }

    /// Set the host
    /// - parameter host: The host
    /// - returns: `self`
    func setHost(_ host: String) -> Self {
        guard !host.isEmpty else {
            return self
        }
        components.host = host
        return self
    }

    /// Set port
    /// - parameter port: The port
    /// - returns: `self`
    func setPort(_ port: UInt) -> Self {
        components.port = Int(port)
        return self
    }

    /// Set the path
    /// - parameter path: The path
    /// - returns: `self`
    func setPath(_ path: String) -> Self {
        guard !path.isEmpty else {
            return self
        }
        components.path = "/\(path)".replacingOccurrences(of: "//", with: "/")
        return self
    }

    /// Set the path
    /// - parameter path: The path
    /// - returns: `self`
    func appendPath(_ path: String) -> Self {
        guard !path.isEmpty else {
            return self
        }
        components.path = "\(components.path)/\(path)".replacingOccurrences(of: "//", with: "/")
        return self
    }
}

// MARK: - Fragment
public extension URLRequestBuilder {

    /// Set the fragment
    /// - parameter fragment: The fragment
    /// - returns: `self`
    func setFragment(_ fragment: String) -> Self {
        guard !fragment.isEmpty else {
            return self
        }
        components.fragment = fragment
        return self
    }
}

// MARK: - URLRequestConvertible
extension URLRequestBuilder: URLRequestConvertible {
    public func buildRequest(baseUrl _: URL?, encoder _: JSONEncoder) throws -> URLRequest {
        guard let result = build() else {
            throw ApiError.requestEncodingFailed
        }
        return result
    }
}
