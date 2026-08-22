import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import RoundTrip
import Testing

@Suite(.serialized) struct URLRequestExtTests {

    @Test func addHeaderWithName() throws {
        var request = URLRequest(url: try testURL())
        request.add(header: "value", named: "X-Custom-Header")
        #expect(request.value(forHTTPHeaderField: "X-Custom-Header") == "value")
    }

    @Test func addMultipleHeaders() throws {
        var request = URLRequest(url: try testURL())
        request.add(header: "value1", named: "Header1")
        request.add(header: "value2", named: "Header2")
        #expect(request.value(forHTTPHeaderField: "Header1") == "value1")
        #expect(request.value(forHTTPHeaderField: "Header2") == "value2")
    }

    @Test func addHeaderOverwritesPrevious() throws {
        var request = URLRequest(url: try testURL())
        request.add(header: "first", named: "X-Header")
        request.add(header: "second", named: "X-Header")
        #expect(request.value(forHTTPHeaderField: "X-Header") == "second")
    }

    private func testURL() throws -> URL {
        try #require(URL(string: "https://example.com"))
    }
}
