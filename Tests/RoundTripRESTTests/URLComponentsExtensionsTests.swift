import Foundation
import RoundTrip
@testable import RoundTripREST
import Testing

@Suite(.serialized) struct URLComponentsExtensionsTests {
    @Test func createsPathAndSortedQueryParameters() throws {
        let base = try #require(URL(string: "https://api.example.com/v1"))
        let parameters: [String: any FormEncodable] = ["zebra": "z", "apple": "a", "middle": "m"]
        let result = try URLComponents.create(baseUrl: base, path: "/users", queryParams: parameters)
        #expect(result.absoluteString.hasPrefix("https://api.example.com/users?"))
        let value = result.absoluteString
        let apple = try #require(value.range(of: "apple")).lowerBound
        let middle = try #require(value.range(of: "middle")).lowerBound
        let zebra = try #require(value.range(of: "zebra")).lowerBound
        #expect(apple < middle)
        #expect(middle < zebra)
    }

    @Test func appendsToExistingQueryAndEncodesValues() throws {
        let url = try #require(URL(string: "https://api.example.com/users?existing=value"))
        let parameters: [String: any FormEncodable] = ["a&b c": "x&y=z", "name": "John Doe"]
        let result = try URLComponents.create(url: url, queryParams: parameters)
        #expect(result.absoluteString.contains("existing=value"))
        #expect(result.absoluteString.contains("a%26b%20c=x%26y%3Dz"))
        #expect(result.absoluteString.contains("name=John%20Doe"))
    }

    @Test func supportsPrimitiveFormValuesAndEmptyParameters() throws {
        let url = try #require(URL(string: "https://api.example.com"))
        let parameters: [String: any FormEncodable] = ["count": 42, "active": true, "price": 19.99]
        let result = try URLComponents.create(url: url, queryParams: parameters)
        #expect(result.absoluteString.contains("count=42"))
        #expect(result.absoluteString.contains("active=true"))
        #expect(result.absoluteString.contains("price=19.99"))
        let unchanged = try URLComponents.create(url: url, queryParams: [:])
        #expect(unchanged == url)
    }
}
