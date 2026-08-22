import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import RoundTrip
import Testing

@Suite(.serialized) struct URLRequestBuilderMethodTests {

    @Test func methodGet() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.get)
        let request = try #require(builder.build())
        #expect(request.httpMethod == "GET")
    }

    @Test func methodPost() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.post)
        let request = try #require(builder.build())
        #expect(request.httpMethod == "POST")
    }

    @Test func methodPut() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.put)
        let request = try #require(builder.build())
        #expect(request.httpMethod == "PUT")
    }

    @Test func methodDelete() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.delete)
        let request = try #require(builder.build())
        #expect(request.httpMethod == "DELETE")
    }

    @Test func methodPatch() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.patch)
        let request = try #require(builder.build())
        #expect(request.httpMethod == "PATCH")
    }

    @Test func methodHead() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.head)
        let request = try #require(builder.build())
        #expect(request.httpMethod == "HEAD")
    }

    @Test func methodConnect() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.connect)
        let request = try #require(builder.build())
        #expect(request.httpMethod == "CONNECT")
    }

    @Test func methodOptions() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.options)
        let request = try #require(builder.build())
        #expect(request.httpMethod == "OPTIONS")
    }

    @Test func methodTrace() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .setMethod(.trace)
        let request = try #require(builder.build())
        #expect(request.httpMethod == "TRACE")
    }

    @Test func methodDebugDescription() {
        let method = URLRequestBuilder.Method.get
        // Access the method's rawValue to cover debugDescription
        #expect(method.rawValue == "GET")
    }
}
