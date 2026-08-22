# RoundTrip

RoundTrip provides HTTP request construction and async URLSession operations for Apple platforms. RoundTripREST adds a client for APIs with a shared base URL, default headers, response validation, and JSON decoding.

## Platform support

RoundTrip supports iOS 18, macOS 15, tvOS 18, watchOS 11, and visionOS 2. Linux is not supported.

## Install

Add RoundTrip to a Swift Package Manager manifest:

```swift
dependencies: [
    .package(
        url: "https://github.com/modern-swift-dev/roundtrip-swift.git",
        from: "1.0.0"
    )
]
```

Add one or both products to the target that uses them:

```swift
.product(name: "RoundTrip", package: "roundtrip-swift"),
.product(name: "RoundTripREST", package: "roundtrip-swift")
```

For local development against a checkout, use a path dependency instead:

```swift
.package(path: "../roundtrip-swift")
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

Read the [RoundTrip documentation](https://modern-swift-dev.github.io/roundtrip-swift/) on GitHub Pages. Start with the [installation and request guide](https://modern-swift-dev.github.io/roundtrip-swift/documentation/getting-started/), then use the generated DocC references for [RoundTrip](https://modern-swift-dev.github.io/roundtrip-swift/api/roundtrip/documentation/roundtrip/) and [RoundTripREST](https://modern-swift-dev.github.io/roundtrip-swift/api/roundtrip-rest/).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). RoundTrip is available under the MIT license. See [LICENSE](LICENSE).
