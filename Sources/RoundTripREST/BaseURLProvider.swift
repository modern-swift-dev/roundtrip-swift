import Foundation

/// Protocol for providing base URLs to REST clients.
/// Useful for switching between different environments (staging/production).
public protocol BaseURLProvider: Sendable {
    /// The base URL for API requests.
    /// - Returns: URL to use as prefix for all API requests
    var baseURL: URL? { get }
}
