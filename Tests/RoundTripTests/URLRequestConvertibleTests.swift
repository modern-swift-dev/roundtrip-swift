import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import RoundTrip
import Testing

@Suite(.serialized) struct URLRequestConvertibleTests {
    private static let testURL = URL(string: "https://api.example.com/test") ?? URL(fileURLWithPath: "/")
    private static let otherURL = URL(string: "https://other.com") ?? URL(fileURLWithPath: "/")

    // MARK: - URL Conformance Tests

    @Test func urlBuildRequest() throws {
        let request = try Self.testURL.buildRequest(baseUrl: nil, encoder: JSONEncoder())
        #expect(request.url == Self.testURL)
    }

    @Test func urlBuildRequestIgnoresBaseURL() throws {
        let request = try Self.testURL.buildRequest(baseUrl: Self.otherURL, encoder: JSONEncoder())
        #expect(request.url == Self.testURL)
    }

    // MARK: - URLRequest Conformance Tests

    @Test func urlRequestBuildRequest() throws {
        let originalRequest = URLRequest(url: Self.testURL)
        let request = try originalRequest.buildRequest(baseUrl: nil, encoder: JSONEncoder())
        #expect(request.url == originalRequest.url)
    }

    @Test func urlRequestBuildRequestPreservesMethod() throws {
        var originalRequest = URLRequest(url: Self.testURL)
        originalRequest.httpMethod = "POST"
        let request = try originalRequest.buildRequest(baseUrl: nil, encoder: JSONEncoder())
        #expect(request.httpMethod == "POST")
    }

    @Test func urlRequestBuildRequestPreservesHeaders() throws {
        var originalRequest = URLRequest(url: Self.testURL)
        originalRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let request = try originalRequest.buildRequest(baseUrl: nil, encoder: JSONEncoder())
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }
}
