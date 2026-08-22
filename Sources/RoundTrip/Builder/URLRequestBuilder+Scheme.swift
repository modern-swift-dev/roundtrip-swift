import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - Scheme
public extension URLRequestBuilder {

    /// The scheme for the request
    enum Scheme: String {

        /// The http
        @available(*, deprecated, message: "use https instead")
        case http

        /// The https
        case https

        /// The file
        case file

        /// Websocket
        case webSocket = "ws"

        /// Secure Websocket
        case secureWebSocket = "wss"

        /// Debug Description
        var debugDescription: String {
            rawValue
        }
    }

    /// Set the scheme
    /// - parameter scheme: The scheme of the request
    /// - returns: `self`
    func setScheme(_ scheme: Scheme) -> Self {
        components.scheme = scheme.rawValue
        return self
    }
}
