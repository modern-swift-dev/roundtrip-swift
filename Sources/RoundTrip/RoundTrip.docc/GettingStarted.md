# Getting started

[Documentation index](<doc:RoundTrip>)

RoundTrip supports iOS 18, macOS 15, tvOS 18, watchOS 11, and visionOS 2. It does not support Linux.

The watchOS lane runs the remaining compatible suites. Five Mocker-backed test files use `#if !os(watchOS)` because watchOS does not route POST and upload requests through a custom `URLProtocol`. The other Apple platforms run those tests.

Add the `RoundTrip` product to an app target. Until the package is published, use a local package dependency:

```swift
.package(path: "../roundtrip-swift")
```

Create a request and execute it with `HttpClient`:

```swift
import RoundTrip

let request = URLRequestBuilder(string: "https://example.com/status")!
    .setMethod(.get)
let response = try await HttpClient().execute(request: request)
try response.checkForStatusCodeValidity(validStatusCode: [200])
```

Use a `URLRequest` directly when a builder adds no value. It already conforms to ``URLRequestConvertible``.
