import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import RoundTrip
import Testing

@Suite(.serialized) struct URLRequestBuilderHeaderTests {

    // MARK: - Custom Header Tests

    @Test func addCustomHeader() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addHeader("X-Custom-Header", value: "custom-value")
        let request = try #require(builder.build())
        #expect(request.value(forHTTPHeaderField: "X-Custom-Header") == "custom-value")
    }

    // MARK: - Authorization Tests

    @Test func addAuthorizationHeader() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addHeader(.authorization("Bearer token123"))
        let request = try #require(builder.build())
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token123")
    }

    // MARK: - Accept Headers Tests

    @Test func addAcceptHeader() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addHeader(.accept(.json))
        let request = try #require(builder.build())
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test func addAcceptRawHeader() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addHeader(.acceptRaw("custom/type"))
        let request = try #require(builder.build())
        #expect(request.value(forHTTPHeaderField: "Accept") == "custom/type")
    }

    @Test func addAcceptEncodingHeader() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addHeader(.acceptEncoding("gzip, deflate"))
        let request = try #require(builder.build())
        #expect(request.value(forHTTPHeaderField: "Accept-Encoding") == "gzip, deflate")
    }

    @Test func addAcceptCharsetHeader() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addHeader(.acceptCharset("utf-8"))
        let request = try #require(builder.build())
        #expect(request.value(forHTTPHeaderField: "Accept-Charset") == "utf-8")
    }

    @Test func addAcceptLanguageHeader() throws {
        let locale = Locale(identifier: "en_US")
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addHeader(.acceptLanguage(locale))
        let request = try #require(builder.build())
        #expect(request.value(forHTTPHeaderField: "Accept-Language") == "en-US")
    }

    @Test func addAcceptLanguageHeaderWithoutRegion() throws {
        let locale = Locale(identifier: "fr")
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addHeader(.acceptLanguage(locale))
        let request = try #require(builder.build())
        #expect(request.value(forHTTPHeaderField: "Accept-Language") == "fr")
    }

    @Test func addAcceptLanguageRawHeader() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addHeader(.acceptLanguageRaw("en-GB"))
        let request = try #require(builder.build())
        #expect(request.value(forHTTPHeaderField: "Accept-Language") == "en-GB")
    }

    // MARK: - Content-Type Headers Tests

    @Test func addContentTypeHeader() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addHeader(.contentType(.json))
        let request = try #require(builder.build())
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func addContentTypeRawHeader() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addHeader(.contentTypeRaw("custom/type"))
        let request = try #require(builder.build())
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "custom/type")
    }

    @Test func addContentLengthHeader() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addHeader(.contentLength(1024))
        let request = try #require(builder.build())
        #expect(request.value(forHTTPHeaderField: "Content-Length") == "1024")
    }

    // MARK: - Conditional Headers Tests

    @Test func addIfModifiedSinceHeader() throws {
        let date = Date(timeIntervalSince1970: 0)
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addHeader(.ifModifiedSince(date))
        let request = try #require(builder.build())
        #expect(request.value(forHTTPHeaderField: "If-Modified-Since") == "Thu, 01 Jan 1970 00:00:00 GMT")
    }

    @Test func addIfUnmodifiedSinceHeader() throws {
        let date = Date(timeIntervalSince1970: 0)
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addHeader(.ifUnmodifiedSince(date))
        let request = try #require(builder.build())
        #expect(request.value(forHTTPHeaderField: "If-Unmodified-Since") == "Thu, 01 Jan 1970 00:00:00 GMT")
    }

    @Test func addIfMatchHeader() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addHeader(.ifMatch("etag-value"))
        let request = try #require(builder.build())
        #expect(request.value(forHTTPHeaderField: "If-Match") == "etag-value")
    }

    @Test func addIfNoneMatchHeader() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addHeader(.ifNoneMatch("etag-value"))
        let request = try #require(builder.build())
        #expect(request.value(forHTTPHeaderField: "If-None-Match") == "etag-value")
    }

    // MARK: - DNT Header Tests

    @Test func addDoNotTrackHeaderTrue() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addHeader(.doNotTrack(true))
        let request = try #require(builder.build())
        #expect(request.value(forHTTPHeaderField: "DNT") == "1")
    }

    @Test func addDoNotTrackHeaderFalse() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addHeader(.doNotTrack(false))
        let request = try #require(builder.build())
        #expect(request.value(forHTTPHeaderField: "DNT") == "0")
    }

}
