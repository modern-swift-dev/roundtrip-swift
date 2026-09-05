# Downloads

[Documentation index](<doc:RoundTrip>)

Use `download(request:to:progress:)` to move a completed download to a destination URL. The destination must be writable and should not already contain a file.

```swift
let destination = try FileManager.default
    .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    .appending(path: "report.pdf")

let request = URLRequestBuilder(string: "https://example.com/report.pdf")!
let response = try await HttpClient().download(request: request, to: destination)
try response.checkForStatusCodeValidity(validStatusCode: [200])
```

Use ``BackgroundHttpClient`` when an Apple app needs system-managed background transfers. Set its `completionHandler` from the application's background-session event callback, and observe `finishedTask` on the main actor.

Releasing a background client lets its existing transfers and delegate callbacks finish. The session then invalidates and releases its resources. Keep the client alive while observing `finishedTask`; its `completionHandler` remains available to the session until background events finish, even after the client is released. Completed downloads are still moved into the download cache.

Cancel a transfer explicitly by calling `cancel()` on the `URLSessionDownloadTask` or `URLSessionUploadTask` returned by the client. Releasing the client does not cancel those tasks. Retain and reuse a client for a given background-session identifier while its transfers are active; do not create a replacement session with that identifier while the previous session is finishing.
