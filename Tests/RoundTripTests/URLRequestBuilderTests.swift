import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import RoundTrip
import Testing

@Suite(.serialized) struct URLRequestBuilderTests {

    // MARK: - Initialization Tests

    @Test func initDefault() throws {
        let builder = URLRequestBuilder()
        let request = try #require(builder.build())
        #expect(request.url?.scheme == "https")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "*/*")
    }

    @Test func initWithString() throws {
        let builder = try #require(URLRequestBuilder(string: "https://api.example.com/v1/users"))
        let request = try #require(builder.build())
        #expect(request.url?.scheme == "https")
        #expect(request.url?.host == "api.example.com")
        #expect(request.url?.path == "/v1/users")
    }

    @Test func initWithInvalidString() {
        let builder = URLRequestBuilder(string: "not a valid url ://")
        #expect(builder == nil)
    }

    @Test func initWithURL() throws {
        let url = try #require(URL(string: "https://api.example.com/v1/users"))
        let builder = try #require(URLRequestBuilder(url: url))
        let request = try #require(builder.build())
        #expect(request.url?.host == "api.example.com")
    }

    @Test func initWithFileURLReturnsNil() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.txt")
        let builder = URLRequestBuilder(url: fileURL)
        #expect(builder == nil)
    }

    @Test func initWithBaseURLAndPath() throws {
        let baseURL = try #require(URL(string: "https://api.example.com"))
        let builder = try #require(URLRequestBuilder(baseURL: baseURL, path: "v1/users"))
        let request = try #require(builder.build())
        #expect(request.url?.path == "/v1/users")
    }

    @Test func initWithBaseURLFileURLReturnsNil() {
        let fileURL = URL(fileURLWithPath: "/tmp")
        let builder = URLRequestBuilder(baseURL: fileURL, path: "test")
        #expect(builder == nil)
    }

    // MARK: - Host and Port Tests

    @Test func setHost() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
        let request = try #require(builder.build())
        #expect(request.url?.host == "api.example.com")
    }

    @Test func setHostEmptyDoesNothing() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setHost("")
        let request = try #require(builder.build())
        #expect(request.url?.host == "api.example.com")
    }

    @Test func setPort() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setPort(8080)
        let request = try #require(builder.build())
        #expect(request.url?.port == 8080)
    }

    // MARK: - Path Tests

    @Test func setPath() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setPath("v1/users")
        let request = try #require(builder.build())
        #expect(request.url?.path == "/v1/users")
    }

    @Test func setPathNormalizesSlashes() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setPath("/v1//users")
        let request = try #require(builder.build())
        #expect(request.url?.path == "/v1/users")
    }

    @Test func setPathEmptyDoesNothing() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setPath("initial")
            .setPath("")
        let request = try #require(builder.build())
        #expect(request.url?.path == "/initial")
    }

    @Test func appendPath() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setPath("v1")
            .appendPath("users")
            .appendPath("123")
        let request = try #require(builder.build())
        #expect(request.url?.path == "/v1/users/123")
    }

    @Test func appendPathEmptyDoesNothing() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setPath("v1")
            .appendPath("")
        let request = try #require(builder.build())
        #expect(request.url?.path == "/v1")
    }

    // MARK: - Fragment Tests

    @Test func setFragment() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setFragment("section1")
        let request = try #require(builder.build())
        #expect(request.url?.fragment == "section1")
    }

    @Test func setFragmentEmptyDoesNothing() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setFragment("section1")
            .setFragment("")
        let request = try #require(builder.build())
        #expect(request.url?.fragment == "section1")
    }

    // MARK: - Service Type Tests

    @Test func setServiceType() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setServiceType(.video)
        let request = try #require(builder.build())
        #expect(request.networkServiceType == .video)
    }

    // MARK: - URLRequestConvertible Tests

    @Test func buildRequestSuccess() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
        let request = try builder.buildRequest(baseUrl: nil, encoder: .init())
        #expect(request.url?.host == "api.example.com")
    }

}
