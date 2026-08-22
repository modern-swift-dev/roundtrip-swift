# Cancellation and concurrency

[Documentation index](<doc:RoundTrip>)

`HttpClient` is `Sendable` and may be shared by concurrent tasks. Treat request values and decoded models according to their own concurrency requirements.

Treat cancellation as a normal outcome when a screen or parent task goes away. Handle `ApiError.cancelled` or `URLError.cancelled` where the calling feature needs to distinguish cancellation from a failed request.

To stop all work owned by an `HttpClient`, call `invalidate()`. Pass `recreate: true` only when you intend to use that client again after invalidating its current URL session.

`WSSClient` and `BackgroundHttpClient` have APIs that interact with Combine and the main actor. Receive UI updates on the main actor, and keep long-running transfer ownership outside short-lived views.
