# RoundTrip

RoundTrip provides HTTP request construction and async URLSession operations for Apple platforms. RoundTripREST adds a client for APIs with a shared base URL, default headers, response validation, and JSON decoding.

## Platform support

RoundTrip supports iOS 18, macOS 15, tvOS 18, watchOS 11, and visionOS 2. Linux is not supported.

## Install

The package has no published remote or release tag yet. For local development, add the checkout by path:

```swift
dependencies: [
    .package(path: "../roundtrip-swift")
]
```

Add one or both products to the target that uses them:

```swift
.product(name: "RoundTrip", package: "roundtrip-swift"),
.product(name: "RoundTripREST", package: "roundtrip-swift")
```

Replace the following placeholders after a remote and first release tag exist:

```swift
// .package(url: "<ROUNDTRIP-REPOSITORY-URL>", from: "<ROUNDTRIP-FIRST-RELEASE>")
```

## Async request

```swift
import Foundation
import RoundTrip

struct User: Decodable {
    let id: Int
    let name: String
}

let request = URLRequestBuilder(string: "https://example.com/users/42")!
    .setMethod(.get)

let client = HttpClient()
let response = try await client.execute(request: request)
try response.checkForStatusCodeValidity(validStatusCode: [200])

guard let user = response.payloadAs(User.self) else {
    throw ApiError.responseDecodingFailed(response.data, ApiError.emptyResponseBody)
}
print(user.name)
```

## REST request

```swift
import Combine
import Foundation
import RoundTrip
import RoundTripREST

struct APIBaseURL: BaseURLProvider {
    let baseURL = URL(string: "https://example.com")
}

struct NoAPIKey: ApiKeyProvider {
    var apiKey: String? { get async { nil } }
}

struct UserRequest: URLRequestConvertible {
    let id: Int

    func buildRequest(baseUrl: URL?, encoder: JSONEncoder) throws -> URLRequest {
        guard let baseUrl else { throw ApiError.invalidURL }
        return URLRequest(url: baseUrl.appending(path: "users/\(id)"))
    }
}

struct User: Decodable {
    let id: Int
    let name: String
}

let rest = RestClient(
    baseURLProvider: APIBaseURL(),
    apiKeyProvider: NoAPIKey(),
    service: NetworkService(),
    headerProvider: nil,
    errorSubject: PassthroughSubject<ApiError, Never>()
)
let result: ApiOperationResult<User> = try await rest.execute(request: UserRequest(id: 42))
print(result.value.name)
```

## Documentation

Build DocC locally to browse the guides included with the `RoundTrip` and `RoundTripREST` products. The package has no hosted documentation URL yet.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). RoundTrip is available under the MIT license. See [LICENSE](LICENSE).
