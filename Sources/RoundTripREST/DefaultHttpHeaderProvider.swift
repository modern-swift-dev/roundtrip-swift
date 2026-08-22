/// Protocol for providing default HTTP headers.
/// Headers will be included in all requests made by the REST client.
public protocol DefaultHttpHeaderProvider: Sendable {
    /// Returns default headers to include in requests
    /// - Returns: Dictionary of header names and values
    func provideDefaultHeaders() -> [String: String]
}
