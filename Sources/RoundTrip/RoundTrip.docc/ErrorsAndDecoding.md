# Errors and decoding

[Documentation index](<doc:RoundTrip>)

RoundTrip reports its library errors as ``ApiError``. URLSession failures may still arrive as their original error in async operations, so map them with `error.asApiError` when your application wants one error type.

Check response status before decoding. ``ApiResponse/payloadAs(_:)`` returns nil when there is no body or decoding fails. Use a throwing `JSONDecoder` when the underlying decoding error matters.

```swift
do {
    let response = try await HttpClient().execute(request: request)
    try response.checkForStatusCodeValidity(validStatusCode: [200])
    let user = try JSONDecoder().decode(User.self, from: response.data ?? Data())
    print(user)
} catch let error as ApiError {
    switch error {
    case let .invalidStatusCode(code, _):
        print("Server returned \(code)")
    case .cancelled:
        break
    default:
        throw error
    }
}
```
