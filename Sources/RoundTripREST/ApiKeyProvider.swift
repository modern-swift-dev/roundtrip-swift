/// Protocol for providing API keys to REST clients.
/// Implementations should handle API key storage and refresh.
public protocol ApiKeyProvider: Sendable {
    /// The current API key, if available.
    /// - Returns: String value of API key or nil if not available
    var apiKey: String? { get async }
}
