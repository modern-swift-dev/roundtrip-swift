#if !os(watchOS)
    import Foundation
    import RoundTrip
    import Testing

    @Suite(.serialized) struct DateFormatterHttpHeaderTestCase {

        @Test func serialize() throws {
            let easternTime = try #require(TimeZone(identifier: "America/New_York"))
            let value = try RoundTripTestSupport.date(
                year: 2021,
                month: 03,
                day: 28,
                hour: 08,
                minute: 14,
                second: 46,
                timeZone: easternTime
            )

            let result = DateFormatter.httpHeaderFormatter.string(from: value)

            #expect(result == "Sun, 28 Mar 2021 12:14:46 GMT")
        }

        @Test func parse() throws {
            let easternTime = try #require(TimeZone(identifier: "America/New_York"))
            let reference = try RoundTripTestSupport.date(
                year: 2021,
                month: 03,
                day: 28,
                hour: 08,
                minute: 14,
                second: 46,
                timeZone: easternTime
            )

            let value = "Sun, 28 Mar 2021 12:14:46 GMT"
            let date = DateFormatter.httpHeaderFormatter.date(from: value)

            #expect(date == reference)
        }
    }
#endif
