import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import RoundTrip
import Testing

@Suite(.serialized) struct ApiResponseTests {

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

    // MARK: - Initialization Tests

    @Test func initWithDataAndResponse() throws {
        let data = "test".data(using: .utf8)
        let response = try createHTTPURLResponse(statusCode: 200)
        let apiResponse = ApiResponse(data: data, response: response)

        #expect(apiResponse.data == data)
        #expect(apiResponse.statusCode == 200)
        #expect(apiResponse.file == nil)
    }

    @Test func initWithFileAndResponse() throws {
        let fileURL = URL(fileURLWithPath: "/tmp/test.txt")
        let response = try createHTTPURLResponse(statusCode: 200)
        let apiResponse = ApiResponse(file: fileURL, response: response)

        #expect(apiResponse.file == fileURL)
        #expect(apiResponse.statusCode == 200)
        #expect(apiResponse.data == nil)
    }

    @Test func initWithNonHTTPURLResponse() throws {
        let data = "test".data(using: .utf8)
        let testURL = try #require(URL(string: "https://example.com"))
        let response = URLResponse(
            url: testURL,
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )
        let apiResponse = ApiResponse(data: data, response: response)

        #expect(apiResponse.statusCode == 0)
    }

    @Test func initForTests() {
        let data = "test".data(using: .utf8)
        let apiResponse = ApiResponse(
            status: 201,
            data: data,
            mimeType: "application/json",
            headers: ["X-Custom": "value"]
        )

        #expect(apiResponse.statusCode == 201)
        #expect(apiResponse.data == data)
        #expect(apiResponse.mimeType == "application/json")
        #expect(apiResponse.headers["X-Custom"] as? String == "value")
    }

    // MARK: - Status Code Tests

    @Test func is200() {
        let response = ApiResponse(status: 200)
        #expect(response.is200 == true)
        #expect(response.is201 == false)
    }

    @Test func is201() {
        let response = ApiResponse(status: 201)
        #expect(response.is201 == true)
        #expect(response.is200 == false)
    }

    @Test func is20xWith200() {
        let response = ApiResponse(status: 200)
        #expect(response.is20x == true)
    }

    @Test func is20xWith201() {
        let response = ApiResponse(status: 201)
        #expect(response.is20x == true)
    }

    @Test func is20xWith299() {
        let response = ApiResponse(status: 299)
        #expect(response.is20x == true)
    }

    @Test func is20xWith300IsFalse() {
        let response = ApiResponse(status: 300)
        #expect(response.is20x == false)
    }

    @Test func is304() {
        let response = ApiResponse(status: 304)
        #expect(response.is304 == true)
    }

    @Test func is400() {
        let response = ApiResponse(status: 400)
        #expect(response.is400 == true)
    }

    @Test func is401() {
        let response = ApiResponse(status: 401)
        #expect(response.is401 == true)
    }

    @Test func is403() {
        let response = ApiResponse(status: 403)
        #expect(response.is403 == true)
    }

    @Test func is404() {
        let response = ApiResponse(status: 404)
        #expect(response.is404 == true)
    }

    @Test func is50xWith500() {
        let response = ApiResponse(status: 500)
        #expect(response.is50x == true)
    }

    @Test func is50xWith503() {
        let response = ApiResponse(status: 503)
        #expect(response.is50x == true)
    }

    @Test func is50xWith599() {
        let response = ApiResponse(status: 599)
        #expect(response.is50x == true)
    }

    @Test func is50xWith600IsFalse() {
        let response = ApiResponse(status: 600)
        #expect(response.is50x == false)
    }

    // MARK: - Payload Decoding Tests

    struct TestModel: Codable, Equatable {
        let id: Int
        let name: String
    }

    @Test func payloadAsSuccess() throws {
        let model = TestModel(id: 1, name: "test")
        let jsonData = try JSONEncoder().encode(model)
        let response = ApiResponse(status: 200, data: jsonData)

        let decoded: TestModel? = response.payloadAs(TestModel.self)
        #expect(decoded == model)
    }

    @Test func payloadAsWithNilData() {
        let response = ApiResponse(status: 200, data: nil)
        let decoded: TestModel? = response.payloadAs(TestModel.self)
        #expect(decoded == nil)
    }

    @Test func payloadAsWithInvalidJSON() {
        let invalidData = "not json".data(using: .utf8)
        let response = ApiResponse(status: 200, data: invalidData)
        let decoded: TestModel? = response.payloadAs(TestModel.self)
        #expect(decoded == nil)
    }

    // MARK: - Status Code Validation Tests

    @Test func checkForStatusCodeValiditySuccess() throws {
        let response = ApiResponse(status: 200)
        try response.checkForStatusCodeValidity(validStatusCode: [200, 201])
    }

    @Test func checkForStatusCodeValidityFailure() {
        let response = ApiResponse(status: 404)
        do {
            try response.checkForStatusCodeValidity(validStatusCode: [200, 201])
            Issue.record("Should have thrown")
        } catch let error as ApiError {
            if case let .invalidStatusCode(code, _) = error {
                #expect(code == 404)
            } else {
                Issue.record("Wrong error type")
            }
        } catch {
            Issue.record("Unexpected error type")
        }
    }

    // MARK: - Headers Tests

    @Test func headersWithStringValue() throws {
        let httpResponse = try createHTTPURLResponse(statusCode: 200, headers: ["X-Custom": "value"])
        let response = ApiResponse(data: nil, response: httpResponse)
        #expect(response.headers["X-Custom"] as? String == "value")
    }

    @Test func mimeType() throws {
        let httpResponse = try createHTTPURLResponse(statusCode: 200, headers: ["Content-Type": "application/json; charset=utf-8"])
        let response = ApiResponse(data: nil, response: httpResponse)
        #expect(response.mimeType == "application/json")
    }
}
