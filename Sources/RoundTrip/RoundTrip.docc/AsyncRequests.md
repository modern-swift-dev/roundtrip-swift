# Async requests

[Documentation index](<doc:RoundTrip>)

`HttpClient.execute(request:)` returns an ``ApiResponse`` with response data, status code, MIME type, and HTTP headers.

```swift
struct Profile: Decodable {
    let name: String
}

let request = URLRequestBuilder(string: "https://example.com/profile")!
let response = try await HttpClient().execute(request: request)
try response.checkForStatusCodeValidity(validStatusCode: [200])

guard let profile = response.payloadAs(Profile.self) else {
    throw ApiError.responseDecodingFailed(response.data, ApiError.emptyResponseBody)
}
```

For an in-memory upload, call `upload(request:data:progress:)`. For a file, call `fileUpload(request:from:progress:)`. Both return `ApiResponse`; validate the status and decode the body just as you would for a data request.
