import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import RoundTrip
@testable import RoundTripREST
import Testing

@Suite(.serialized) struct URLRequestExtensionsTests {
    private func url() throws -> URL {
        try #require(URL(string: "https://api.example.com/users"))
    }

    @Test func initializesWithPathAndQuery() throws {
        let parameters: [String: any FormEncodable] = ["page": 1, "a&b c": "x&y=z"]
        let request = try URLRequest(url: url(), queryParams: parameters)
        #expect(request.url?.absoluteString.contains("page=1") == true)
        #expect(request.url?.query?.contains("a%26b%20c=x%26y%3Dz") == true)
        let base = try #require(URL(string: "https://api.example.com"))
        #expect(try URLRequest(baseUrl: base, path: "/users", queryParams: nil).url == url())
    }

    @Test func configuresHTTPMethodsAndHeaders() throws {
        var request = URLRequest(url: try url())
        request.post()
        request.put()
        request.delete()
        request.patch()
        request.get()
        request.acceptJson()
        request.contentJson()
        request.authorization("key")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "key")
        request.bearerTokenAuthorization("token")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
    }

    @Test func encodesCodableBodyAndJSONConveniences() throws {
        struct Body: Codable, Equatable { let name: String; let value: Int }
        let body = Body(name: "test", value: 42)
        var request = URLRequest(url: try url())
        try request.codableBody(body, encoder: JSONEncoder())
        let encodedBody = try #require(request.httpBody)
        #expect(try JSONDecoder().decode(Body.self, from: encodedBody) == body)
        try request.postJson(authorizations: "token", body: body, encoder: JSONEncoder(), isBearerToken: true)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        request.deleteJson(authorizations: "key")
        #expect(request.httpMethod == "DELETE")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "key")
    }
}
