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
