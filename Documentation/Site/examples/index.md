---
title: "RoundTrip examples"
description: "Compiled RoundTrip request and REST client examples."
---

Examples

# Compiled examples from the repository

The `Examples` package uses the local checkout, so its source is checked against the current API.

## Run without network access

```sh
swift run --package-path Examples BasicUsage
swift test --package-path Examples
```

The executable constructs a GET request for `https://example.com?source=basic-usage` and prepares the same request with `RestClient`. It sends nothing unless you pass `--execute`.

## Build a request

```swift
let request = builder
    .setMethod(.get)
    .addHeader(.accept(.json))
    .addQueryParam(name: "source", value: "basic-usage")
    .build()
```

## Configure a REST client

```swift
let restClient = RestClient(
    baseURLProvider: ExampleBaseURLProvider(),
    apiKeyProvider: ExampleAPIKeyProvider(),
    service: NetworkService(),
    headerProvider: nil,
    errorSubject: PassthroughSubject<ApiError, Never>()
)
```

[Open the complete example source](https://github.com/modern-swift-dev/roundtrip-swift/tree/main/Examples).
