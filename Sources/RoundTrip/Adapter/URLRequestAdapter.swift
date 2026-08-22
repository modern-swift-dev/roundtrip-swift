import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Protocol for modifying URLRequests before they are executed.
/// Commonly used for adding authentication headers or other request preprocessing.
///
/// Example:
/// ```swift
/// struct AuthAdapter: URLRequestAdapter {
///     func adapt(_ request: URLRequest) -> URLRequest {
///         var request = request
///         request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
///         return request
///     }
/// }
/// ```
public protocol URLRequestAdapter {

    /// Adapt the request.
    ///
    /// Note: The request may already have headers in place that conflicts
    /// with what you are trying to do. Make sure that you clean-up
    /// whatever you are trying to adapt before submitting, or
    /// certain requests may back-fire depending on the back-end implementation.
    ///
    /// - parameter request: The original request
    /// - returns: The new request
    func adapt(_ request: URLRequest) -> URLRequest
}
