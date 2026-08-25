import Foundation
import RoundTrip

/// Executes a request without applying access-token refresh behavior.
public typealias NetworkRequestExecutor = @Sendable (URLRequest) async throws -> ApiResponse

/// Refreshes an expired bearer access token.
public protocol AccessTokenRefresher: AnyObject, Sendable {
    /// Returns a replacement token for the failed token, or `nil` when the
    /// request should not be retried.
    /// Use `execute` for the refresh request so it does not recursively refresh.
    func refreshAccessToken(
        after failedAccessToken: String,
        execute: @escaping NetworkRequestExecutor
    ) async throws -> String?
}
