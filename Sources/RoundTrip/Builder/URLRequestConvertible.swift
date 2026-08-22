import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// The protocol for converting an object (or more likely an enum)
/// to an URL Request
public protocol URLRequestConvertible {

    /// Convert this object to an URL Request
    /// - returns: The final URLRequest
    /// - throws: Any error that occurs during the request creation.
    func buildRequest(baseUrl: URL?, encoder: JSONEncoder) throws -> URLRequest
}

/// Simple extension for cleaner code
extension URL: URLRequestConvertible {
    public func buildRequest(baseUrl _: URL?, encoder _: JSONEncoder) throws -> URLRequest {
        URLRequest(url: self)
    }
}

/// Simple extension for cleaner code
extension URLRequest: URLRequestConvertible {
    public func buildRequest(baseUrl _: URL?, encoder _: JSONEncoder) throws -> URLRequest {
        self
    }
}
