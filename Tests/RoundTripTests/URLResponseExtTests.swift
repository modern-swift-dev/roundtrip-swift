import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import RoundTrip
import Testing

@Suite(.serialized) struct URLResponseExtTests {

    // MARK: - Helper

    private func createHTTPURLResponse(statusCode: Int, headers: [String: String] = [:]) throws -> HTTPURLResponse {
        let testURL = try #require(URL(string: "https://example.com"))
        return try #require(HTTPURLResponse(
            url: testURL,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ))
    }

    private func createURLResponse() -> URLResponse {
        URLResponse(
            url: URL(fileURLWithPath: "/tmp/test"),
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )
    }

    // MARK: - Status Range Tests

    @Test func is2xxWith200() throws {
        let response = try createHTTPURLResponse(statusCode: 200)
        #expect(response.is2xx == true)
    }

    @Test func is2xxWith299() throws {
        let response = try createHTTPURLResponse(statusCode: 299)
        #expect(response.is2xx == true)
    }

    @Test func is2xxWith300IsFalse() throws {
        let response = try createHTTPURLResponse(statusCode: 300)
        #expect(response.is2xx == false)
    }

    @Test func is2xxWithNonHTTPResponse() {
        let response = createURLResponse()
        #expect(response.is2xx == false)
    }

    @Test func is3xxWith300() throws {
        let response = try createHTTPURLResponse(statusCode: 300)
        #expect(response.is3xx == true)
    }

    @Test func is3xxWith399() throws {
        let response = try createHTTPURLResponse(statusCode: 399)
        #expect(response.is3xx == true)
    }

    @Test func is3xxWith400IsFalse() throws {
        let response = try createHTTPURLResponse(statusCode: 400)
        #expect(response.is3xx == false)
    }

    @Test func is3xxWithNonHTTPResponse() {
        let response = createURLResponse()
        #expect(response.is3xx == false)
    }

    @Test func is4xxWith400() throws {
        let response = try createHTTPURLResponse(statusCode: 400)
        #expect(response.is4xx == true)
    }

    @Test func is4xxWith499() throws {
        let response = try createHTTPURLResponse(statusCode: 499)
        #expect(response.is4xx == true)
    }

    @Test func is4xxWith500IsFalse() throws {
        let response = try createHTTPURLResponse(statusCode: 500)
        #expect(response.is4xx == false)
    }

    @Test func is4xxWithNonHTTPResponse() {
        let response = createURLResponse()
        #expect(response.is4xx == false)
    }

    @Test func is5xxWith500() throws {
        let response = try createHTTPURLResponse(statusCode: 500)
        #expect(response.is5xx == true)
    }

    @Test func is5xxWith599() throws {
        let response = try createHTTPURLResponse(statusCode: 599)
        #expect(response.is5xx == true)
    }

    @Test func is5xxWith600IsFalse() throws {
        let response = try createHTTPURLResponse(statusCode: 600)
        #expect(response.is5xx == false)
    }

    @Test func is5xxWithNonHTTPResponse() {
        let response = createURLResponse()
        #expect(response.is5xx == false)
    }

    // MARK: - Specific Status Code Tests

    @Test func is200() throws {
        let response = try createHTTPURLResponse(statusCode: 200)
        #expect(response.is200 == true)
    }

    @Test func is200With201IsFalse() throws {
        let response = try createHTTPURLResponse(statusCode: 201)
        #expect(response.is200 == false)
    }

    @Test func is200WithNonHTTPResponse() {
        let response = createURLResponse()
        #expect(response.is200 == false)
    }

    @Test func is201() throws {
        let response = try createHTTPURLResponse(statusCode: 201)
        #expect(response.is201 == true)
    }

    @Test func is201WithNonHTTPResponse() {
        let response = createURLResponse()
        #expect(response.is201 == false)
    }

    @Test func is302() throws {
        let response = try createHTTPURLResponse(statusCode: 302)
        #expect(response.is302 == true)
    }

    @Test func is302WithNonHTTPResponse() {
        let response = createURLResponse()
        #expect(response.is302 == false)
    }

    @Test func is304() throws {
        let response = try createHTTPURLResponse(statusCode: 304)
        #expect(response.is304 == true)
    }

    @Test func is304WithNonHTTPResponse() {
        let response = createURLResponse()
        #expect(response.is304 == false)
    }

    @Test func is400() throws {
        let response = try createHTTPURLResponse(statusCode: 400)
        #expect(response.is400 == true)
    }

    @Test func is400WithNonHTTPResponse() {
        let response = createURLResponse()
        #expect(response.is400 == false)
    }

    @Test func is401() throws {
        let response = try createHTTPURLResponse(statusCode: 401)
        #expect(response.is401 == true)
    }

    @Test func is401WithNonHTTPResponse() {
        let response = createURLResponse()
        #expect(response.is401 == false)
    }

    @Test func is403() throws {
        let response = try createHTTPURLResponse(statusCode: 403)
        #expect(response.is403 == true)
    }

    @Test func is403WithNonHTTPResponse() {
        let response = createURLResponse()
        #expect(response.is403 == false)
    }

    @Test func is404() throws {
        let response = try createHTTPURLResponse(statusCode: 404)
        #expect(response.is404 == true)
    }

    @Test func is404WithNonHTTPResponse() {
        let response = createURLResponse()
        #expect(response.is404 == false)
    }

    @Test func is500() throws {
        let response = try createHTTPURLResponse(statusCode: 500)
        #expect(response.is500 == true)
    }

    @Test func is500WithNonHTTPResponse() {
        let response = createURLResponse()
        #expect(response.is500 == false)
    }

    @Test func is503() throws {
        let response = try createHTTPURLResponse(statusCode: 503)
        #expect(response.is503 == true)
    }

    @Test func is503WithNonHTTPResponse() {
        let response = createURLResponse()
        #expect(response.is503 == false)
    }

    // MARK: - Header Parsing Tests

    @Test func lastModifiedWithValidDate() throws {
        let response = try createHTTPURLResponse(
            statusCode: 200,
            headers: ["Last-Modified": "Thu, 01 Jan 1970 00:00:00 GMT"]
        )
        #expect(response.lastModified != nil)
        #expect(response.lastModified?.timeIntervalSince1970 == 0)
    }

    @Test func lastModifiedWithInvalidDate() throws {
        let response = try createHTTPURLResponse(
            statusCode: 200,
            headers: ["Last-Modified": "invalid-date"]
        )
        #expect(response.lastModified == nil)
    }

    @Test func lastModifiedWithMissingHeader() throws {
        let response = try createHTTPURLResponse(statusCode: 200)
        #expect(response.lastModified == nil)
    }

    @Test func lastModifiedWithNonHTTPResponse() {
        let response = createURLResponse()
        #expect(response.lastModified == nil)
    }

    @Test func expiresWithValidDate() throws {
        let response = try createHTTPURLResponse(
            statusCode: 200,
            headers: ["Expires": "Thu, 01 Jan 1970 00:00:00 GMT"]
        )
        #expect(response.expires != nil)
        #expect(response.expires?.timeIntervalSince1970 == 0)
    }

    @Test func expiresWithInvalidDate() throws {
        let response = try createHTTPURLResponse(
            statusCode: 200,
            headers: ["Expires": "invalid-date"]
        )
        #expect(response.expires == nil)
    }

    @Test func expiresWithMissingHeader() throws {
        let response = try createHTTPURLResponse(statusCode: 200)
        #expect(response.expires == nil)
    }

    @Test func expiresWithNonHTTPResponse() {
        let response = createURLResponse()
        #expect(response.expires == nil)
    }

    @Test func etagWithValidValue() throws {
        let response = try createHTTPURLResponse(
            statusCode: 200,
            headers: ["ETag": "\"abc123\""]
        )
        #expect(response.etag == "\"abc123\"")
    }

    @Test func etagWithMissingHeader() throws {
        let response = try createHTTPURLResponse(statusCode: 200)
        #expect(response.etag == nil)
    }

    @Test func etagWithNonHTTPResponse() {
        let response = createURLResponse()
        #expect(response.etag == nil)
    }
}
