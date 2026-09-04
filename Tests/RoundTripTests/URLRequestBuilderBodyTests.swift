import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import RoundTrip
import Testing

@Suite(.serialized) struct URLRequestBuilderBodyTests {

    // MARK: - Raw Data Body Tests

    @Test func setBodyData() throws {
        let data = Data("Hello, World!".utf8)
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.post)
            .setBody(data)
        let request = try #require(builder.build())
        #expect(request.httpBody == data)
    }

    @Test func setBodyDataOnGetDoesNotIncludeBody() throws {
        let data = Data("Hello, World!".utf8)
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.get)
            .setBody(data)
        let request = try #require(builder.build())
        #expect(request.httpBody == nil)
    }

    @Test func setBodyDataOnPostIncludesBody() throws {
        let data = Data("Hello, World!".utf8)
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.post)
            .setBody(data)
        let request = try #require(builder.build())
        #expect(request.httpBody == data)
    }

    @Test func setBodyDataOnPutIncludesBody() throws {
        let data = Data("Hello, World!".utf8)
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.put)
            .setBody(data)
        let request = try #require(builder.build())
        #expect(request.httpBody == data)
    }

    @Test func setBodyDataOnPatchIncludesBody() throws {
        let data = Data(#"{"name":"updated"}"#.utf8)
        let request = try #require(URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.patch)
            .setBody(data)
            .build())
        #expect(request.httpMethod == "PATCH")
        #expect(request.httpBody == data)
        #expect(request.value(forHTTPHeaderField: "Content-Length") == String(data.count))
    }

    @Test func setBodyDataOnDeleteIncludesBody() throws {
        let data = Data("Hello, World!".utf8)
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.delete)
            .setBody(data)
        let request = try #require(builder.build())
        #expect(request.httpBody == data)
    }

    // MARK: - JSON Body Tests

    struct TestPayload: Codable, Equatable {
        let name: String
        let value: Int
    }

    @Test func setBodyEncodable() throws {
        let payload = TestPayload(name: "test", value: 42)
        let builder = try URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.post)
            .setBody(payload, encoder: JSONEncoder())
        let request = try #require(builder.build())
        let decoded = try JSONDecoder().decode(TestPayload.self, from: try #require(request.httpBody))
        #expect(decoded == payload)
    }

    // MARK: - Form Encoded Body Tests

    @Test func setBodyFormEncoded() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.post)
            .setBody(formEncoded: [
                .init(name: "username", value: "john"),
                .init(name: "password", value: "secret")
            ])
        let request = try #require(builder.build())
        let bodyData = try #require(request.httpBody)
        let bodyString = try #require(String(data: bodyData, encoding: .utf8))
        #expect(bodyString.contains("username=john"))
        #expect(bodyString.contains("password=secret"))
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
    }

    @Test func setBodyFormEncodedEmpty() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.post)
            .setBody(formEncoded: [])
        let request = try #require(builder.build())
        #expect(request.httpBody == nil)
    }

    @Test func setBodyFormEncodedWithSpecialCharacters() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.post)
            .setBody(formEncoded: [
                .init(name: "email", value: "user@example.com"),
                .init(name: "query", value: "hello world")
            ])
        let request = try #require(builder.build())
        let bodyData = try #require(request.httpBody)
        let bodyString = try #require(String(data: bodyData, encoding: .utf8))
        #expect(bodyString.contains("email=user%40example.com") || bodyString.contains("email=user@example.com"))
    }

    // MARK: - Multipart Body Tests

    @Test func setMultipartBody() throws {
        guard let mpBuilder = try MultipartBody.Builder() else {
            Issue.record("Failed to create builder")
            return
        }

        mpBuilder.addPart(name: "field", part: .init(name: "field", text: "value"))

        let body = try mpBuilder.build()
        defer { body.cleanup() }

        let builder = try URLRequestBuilder()
            .setHost("api.example.com")
            .setBody(body)

        let request = try #require(builder.build())
        #expect(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
    }

    @Test func setMultipartBodyWithBinaryBody() throws {
        guard let mpBuilder = try MultipartBody.Builder() else {
            Issue.record("Failed to create builder")
            return
        }

        mpBuilder.addPart(name: "field", part: .init(name: "field", text: "value"))

        let body = try mpBuilder.build()
        defer { body.cleanup() }

        let builder = try URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.post) // POST method allows body
            .setBody(body, includeBinaryBody: true)

        let request = try #require(builder.build())
        #expect(request.httpBody != nil)
    }
}
