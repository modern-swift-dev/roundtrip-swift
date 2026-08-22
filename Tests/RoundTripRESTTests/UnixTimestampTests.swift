import Foundation
@testable import RoundTripREST
import Testing

@Suite(.serialized) struct UnixTimestampTests {
    private let date = Date(timeIntervalSince1970: 1_700_000_000.123)

    @Test func initializesFromValuesAndDate() {
        #expect(UnixTimestamp(value: 1_700_000_000_000).value == 1_700_000_000_000)
        #expect(UnixTimestamp(value: date).value == 1_700_000_000_123)
        #expect(UnixTimestamp(value: 0).date == Date(timeIntervalSince1970: 0))
    }

    @Test func dateConversionPreservesMilliseconds() {
        let timestamp = UnixTimestamp(value: 1_700_000_000_123)
        #expect(abs(timestamp.date.timeIntervalSince1970 - date.timeIntervalSince1970) < 0.001)
    }

    @Test func encodesAndDecodesBoundaryValues() throws {
        for value in [Int64.max, -1_700_000_000_000, 1_700_000_000_000] {
            let timestamp = UnixTimestamp(value: value)
            let decoded = try JSONDecoder().decode(UnixTimestamp.self, from: JSONEncoder().encode(timestamp))
            #expect(decoded.value == value)
        }
    }

    @Test func decodesJSON() throws {
        let data = try #require("1700000000000".data(using: .utf8))
        #expect(try JSONDecoder().decode(UnixTimestamp.self, from: data).value == 1_700_000_000_000)
    }
}
