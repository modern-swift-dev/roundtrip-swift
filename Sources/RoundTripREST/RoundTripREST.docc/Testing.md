# Testing REST clients

[Documentation index](<doc:RoundTripREST>)

Construct ``NetworkService`` with a `URLSessionConfiguration` whose `protocolClasses` contains a test `URLProtocol` subclass. Pass that service to ``RestClient``. See the [RoundTrip URL loading stub](/api/roundtrip/documentation/roundtrip/testing/) for a complete example.

For tests that only need to inspect request creation or return predetermined responses, implement ``NetworkServiceProtocol`` with a small test double. Keep it local to the test target and have it record the URLRequest passed to `execute`.

Use a fixed `BaseURLProvider`, API key provider, and header provider in the same test. This makes it straightforward to assert that `RestClient.createRequest(_:)` applies the configured base URL and headers.
