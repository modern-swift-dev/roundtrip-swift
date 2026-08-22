# REST errors and decoding

[Documentation index](<doc:RoundTripREST>)

``RestClient`` checks the status codes passed in `validStatusCode` before decoding. It throws `ApiError.invalidStatusCode` for an unexpected response and `ApiError.responseDecodingFailed` when JSON decoding fails.

```swift
struct User: Decodable {
    let id: Int
    let name: String
}

do {
    let result: ApiOperationResult<User> = try await client.execute(
        request: UserRequest(id: 42),
        validStatusCode: [200]
    )
    print(result.value.name)
} catch let error as ApiError {
    switch error {
    case let .invalidStatusCode(status, _):
        print("Unexpected status: \(status)")
    case let .responseDecodingFailed(data, underlying):
        print("Could not decode \(data?.count ?? 0) bytes: \(underlying)")
    default:
        throw error
    }
}
```

Subscribe to the error subject passed to `RestClient` if the app needs to observe REST `ApiError` values centrally. Request-specific code should still handle errors where it starts the request.
