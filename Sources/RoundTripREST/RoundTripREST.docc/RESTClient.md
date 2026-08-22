# REST client

[Documentation index](<doc:RoundTripREST>)

Define small provider types for the base URL, API key, and shared headers. Define request values with `URLRequestConvertible`. A request receives the configured base URL and JSON encoder when the client creates it.

```swift
import Combine
import RoundTrip
import RoundTripREST

struct APIBaseURL: BaseURLProvider {
    let baseURL = URL(string: "https://example.com")
}

struct APIKey: ApiKeyProvider {
    var apiKey: String? { get async { "token" } }
}

struct Headers: DefaultHttpHeaderProvider {
    func provideDefaultHeaders() -> [String: String] {
        ["Accept": "application/json"]
    }
}

struct UserRequest: URLRequestConvertible {
    let id: Int

    func buildRequest(baseUrl: URL?, encoder: JSONEncoder) throws -> URLRequest {
        guard let baseUrl else { throw ApiError.invalidURL }
        return URLRequest(url: baseUrl.appending(path: "users/\(id)"))
    }
}

let client = RestClient(
    baseURLProvider: APIBaseURL(),
    apiKeyProvider: APIKey(),
    service: NetworkService(),
    headerProvider: Headers(),
    errorSubject: PassthroughSubject<ApiError, Never>()
)
```

Call `execute(request:validStatusCode:)` for an `ApiResponse` or give Swift a `Decodable` result type to receive an `ApiOperationResult`. The default valid status code is 200.
