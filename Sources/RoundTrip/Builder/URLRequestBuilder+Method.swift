import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public extension URLRequestBuilder {

    /// The Http Method
    enum Method: String {

        /// Self explanatory
        case get = "GET"

        /// Self explanatory
        case post = "POST"

        /// Self explanatory
        case put = "PUT"

        /// Self explanatory
        case delete = "DELETE"

        /// Self explanatory
        case patch = "PATCH"

        /// Self explanatory
        case head = "HEAD"

        /// Self explanatory
        case connect = "CONNECT"

        /// Self explanatory
        case options = "OPTIONS"

        /// Self explanatory
        case trace = "TRACE"

        var debugDescription: String {
            rawValue
        }
    }

    /// Set method
    /// - parameter method: The HTTP method
    /// - returns: `self`
    func setMethod(_ method: Method) -> Self {
        self.method = method
        return self
    }

}
