# Request construction

[Documentation index](<doc:RoundTrip>)

``URLRequestBuilder`` starts with HTTPS and an `Accept: */*` header. Set the host and path, then add method, headers, query parameters, or a body.

```swift
struct CreateUser: Encodable {
    let name: String
}

guard let request = try URLRequestBuilder()
    .setHost("example.com")
    .setPath("users")
    .setMethod(.post)
    .addHeader(.authorization("Bearer token"))
    .setBody(CreateUser(name: "Ada"))
    .build() else {
    throw ApiError.requestEncodingFailed
}
```

`build()` returns an optional because URL components may not form a valid URL. Treat a nil result as request encoding failure before starting a transfer.

For reusable request definitions, conform a value type to ``URLRequestConvertible``. Its `buildRequest(baseUrl:encoder:)` method lets a REST client supply the base URL and JSON encoder.
