import Foundation
@testable import RoundTripREST
import Testing

@Suite(.serialized) struct PagedResultsTests {
    struct Item: Codable, Sendable, Equatable { let id: Int; let name: String }

    @Test func initializationDerivesHasNext() throws {
        let next = try #require(URL(string: "https://api.example.com/items?page=2"))
        let items = [Item(id: 1, name: "One")]
        #expect(PagedResults(count: 100, next: next, hasNext: true, results: items).hasNext)
        #expect(PagedResults<Item>(count: nil, next: next, results: []).hasNext == false)
        #expect(PagedResults(count: nil, next: nil, results: items).hasNext == false)
        let single = PagedResults(results: items)
        #expect(single.count == 1)
        #expect(single.next == nil)
    }

    @Test func decodesAndEncodes() throws {
        let json = #"{"count":100,"next":"https:\/\/api.example.com\/items?page=2","results":[{"id":1,"name":"One"}]}"#
        let data = try #require(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(PagedResults<Item>.self, from: data)
        #expect(decoded.count == 100)
        #expect(decoded.next?.absoluteString == "https://api.example.com/items?page=2")
        #expect(decoded.hasNext)
        let roundTripped = try JSONDecoder().decode(PagedResults<Item>.self, from: JSONEncoder().encode(decoded))
        #expect(roundTripped.results == decoded.results)
        #expect(roundTripped.next == decoded.next)
    }

    @Test func decodesWithoutOptionalValues() throws {
        let data = try #require(#"{"results":[]}"#.data(using: .utf8))
        let page = try JSONDecoder().decode(PagedResults<Item>.self, from: data)
        #expect(page.count == nil)
        #expect(page.next == nil)
        #expect(!page.hasNext)
    }
}
