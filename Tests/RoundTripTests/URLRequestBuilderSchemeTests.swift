import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import RoundTrip
import Testing

@Suite(.serialized) struct URLRequestBuilderSchemeTests {

    @Test func schemeHTTPS() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setScheme(.https)
        let request = try #require(builder.build())
        #expect(request.url?.scheme == "https")
    }

    @Test func schemeFile() throws {
        let builder = URLRequestBuilder()
            .setHost("localhost")
            .setScheme(.file)
        let request = try #require(builder.build())
        #expect(request.url?.scheme == "file")
    }

    @Test func schemeWebSocket() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setScheme(.webSocket)
        let request = try #require(builder.build())
        #expect(request.url?.scheme == "ws")
    }

    @Test func schemeSecureWebSocket() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setScheme(.secureWebSocket)
        let request = try #require(builder.build())
        #expect(request.url?.scheme == "wss")
    }
}
