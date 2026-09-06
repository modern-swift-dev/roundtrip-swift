---
title: "Getting started with RoundTrip"
description: "Install RoundTrip and send HTTP or REST requests."
---

Getting started

# Build and send a request

## Install the package

```swift
dependencies: [
    .package(
        url: "https://github.com/modern-swift-dev/roundtrip-swift.git",
        from: "1.0.0"
    )
]
```

Add `RoundTrip` for direct HTTP operations. Add `RoundTripREST` when requests share a base URL and client configuration.

```swift
.product(name: "RoundTrip", package: "roundtrip-swift"),
.product(name: "RoundTripREST", package: "roundtrip-swift")
```

## Construct a request

```swift
let request = URLRequestBuilder(string: "https://example.com/users/42")!
    .setMethod(.get)
    .addHeader(.accept(.json))
```

## Execute and decode

```swift
let response = try await HttpClient().execute(request: request)
try response.checkForStatusCodeValidity(validStatusCode: [200])

guard let user = response.payloadAs(User.self) else {
    throw ApiError.responseDecodingFailed(
        response.data,
        ApiError.emptyResponseBody
    )
}
```

Continue with the [examples](/docs/roundtrip-swift/examples/) for query parameters and REST client configuration, or open the [DocC references](/docs/roundtrip-swift/documentation/) for every public symbol.
