# Testing with mocked URL loading

[Documentation index](<doc:RoundTrip>)

Pass a `URLSessionConfiguration` with a custom `URLProtocol` subclass to ``HttpClient/init(configuration:)``. This keeps tests local and lets each test control the status code and body.

```swift
final class StubURLProtocol: URLProtocol {
    static var response = HTTPURLResponse(
        url: URL(string: "https://example.com")!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    )!
    static var data = Data("{\"name\":\"Ada\"}".utf8)

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        client?.urlProtocol(self, didReceive: Self.response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

var configuration = URLSessionConfiguration.ephemeral
configuration.protocolClasses = [StubURLProtocol.self]
let client = HttpClient(configuration: configuration)
```

Reset static stub state in test teardown. Serialize tests that share a stub type, or give each test its own URLProtocol subclass.
