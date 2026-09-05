import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import RoundTrip
import Testing

@Suite(.serialized) struct URLRequestBuilderQueryTests {

    // MARK: - Query Parameter Tests

    @Test func addQueryParam() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addQueryParam(name: "page", value: 1)
        let request = try #require(builder.build())
        #expect(request.url?.query?.contains("page=1") == true)
    }

    @Test func addMultipleQueryParams() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addQueryParam(name: "page", value: 1)
            .addQueryParam(name: "limit", value: 20)
        let request = try #require(builder.build())
        #expect(request.url?.query?.contains("page=1") == true)
        #expect(request.url?.query?.contains("limit=20") == true)
    }

    @Test func addQueryParamWithString() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addQueryParam(name: "search", value: "hello")
        let request = try #require(builder.build())
        #expect(request.url?.query?.contains("search=hello") == true)
    }

    @Test func addQueryParamWithSpecialCharacters() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addQueryParam(name: "query", value: "hello+world")
        let request = try #require(builder.build())
        // + should be encoded
        #expect(request.url?.query?.contains("query=hello%2Bworld") == true)
    }

    @Test func addQueryParamWithSlash() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addQueryParam(name: "path", value: "a/b")
        let request = try #require(builder.build())
        // / should be encoded
        #expect(request.url?.query?.contains("path=a%2Fb") == true)
    }

    @Test func addQueryParamEncodesDelimitersInNameAndValue() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addQueryParam(name: "a&b c", value: "x&y=z")
        let request = try #require(builder.build())

        #expect(request.url?.query == "a%26b%20c=x%26y%3Dz")
    }

    @Test func incrementallyAddsManyParametersWithoutChangingExistingEncoding() throws {
        let builder = try #require(URLRequestBuilder(string: "https://example.com/path?existing=%2f&flag#fragment"))
        for index in 0 ..< 2000 {
            _ = builder.addQueryParam(name: "item", value: index)
        }
        let firstRequest = try #require(builder.build())
        let firstURL = try #require(firstRequest.url)
        let components = try #require(URLComponents(url: firstURL, resolvingAgainstBaseURL: false))
        #expect(components.percentEncodedQueryItems?.first?.value == "%2f")
        #expect(components.queryItems?.count == 2002)
        #expect(components.queryItems?[1] == URLQueryItem(name: "flag", value: nil))
        #expect(components.queryItems?.last == URLQueryItem(name: "item", value: "1999"))
        #expect(components.fragment == "fragment")

        _ = builder.setPath("updated").addQueryParams([.init(name: "a&b", value: "x+y")])
        let secondRequest = try #require(builder.build())
        #expect(secondRequest.url?.path == "/updated")
        #expect(secondRequest.url?.query?.hasSuffix("a%26b=x%2By") == true)
        #expect(firstRequest.url == firstURL)
    }

    // MARK: - Query Params Array Tests

    @Test func addQueryParams() throws {
        let params: [URLRequestBuilder.FormParameter] = [
            .init(name: "page", value: 1),
            .init(name: "limit", value: 20),
            .init(name: "sort", value: "name")
        ]
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addQueryParams(params)
        let request = try #require(builder.build())
        #expect(request.url?.query?.contains("page=1") == true)
        #expect(request.url?.query?.contains("limit=20") == true)
        #expect(request.url?.query?.contains("sort=name") == true)
    }

    @Test func addQueryParamsEmpty() throws {
        let builder = URLRequestBuilder()
            .setHost("api.example.com")
            .addQueryParams([])
        let request = try #require(builder.build())
        #expect(request.url?.query == nil)
    }
}
