# Request adapters

[Documentation index](<doc:RoundTrip>)

Conform to ``URLRequestAdapter`` to derive a request with headers or other changes. `URLSession.DataTaskPublisher.adapt(_:)` applies the adapter before returning a replacement publisher.

```swift
import Combine
import RoundTrip

struct BearerToken: URLRequestAdapter {
    let token: String

    func adapt(_ request: URLRequest) -> URLRequest {
        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}

let publisher = URLSession.shared
    .dataTaskPublisher(for: URL(string: "https://example.com/me")!)
    .adapt(BearerToken(token: "secret"))
```

Adapters are a Combine utility. For async requests, apply the same request mutation before passing the request to `HttpClient`.
