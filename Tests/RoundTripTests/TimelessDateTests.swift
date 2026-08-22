import Foundation
import RoundTrip
import Testing

@Suite(.serialized) struct TimelessDateTests {

    // MARK: - Initialization Tests

    @Test func initWithValidValues() {
        let date = TimelessDate(year: 2024, month: 6, day: 15)
        #expect(date.year == 2024)
        #expect(date.month == 6)
        #expect(date.day == 15)
    }

    @Test func initClampsYear() {
        let date = TimelessDate(year: 10000, month: 6, day: 15)
        #expect(date.year == 9999)
    }

    // MARK: - asDate Tests

    @Test func asDateWithUTC() {
        let timelessDate = TimelessDate(year: 2024, month: 1, day: 1)
        let date = timelessDate.asDate(timeZone: .gmt)
        #expect(date != nil)
    }

    @Test func asDateDefault() {
        let timelessDate = TimelessDate(year: 2024, month: 6, day: 15)
        let date = timelessDate.asDate
        #expect(date != nil)
    }

    // MARK: - asString Tests

    @Test func asString() {
        let timelessDate = TimelessDate(year: 2024, month: 6, day: 15)
        let string = timelessDate.asString
        #expect(string != nil)
        #expect(string?.contains("2024") == true)
    }

    // MARK: - FormEncodable Tests

    @Test func formEncodableValue() {
        let timelessDate = TimelessDate(year: 2024, month: 6, day: 15)
        let result = timelessDate.formEncodableValue()
        #expect(result.contains("2024"))
    }

    @Test func formEncodableFallback() {
        // Even with invalid values, should return a fallback
        let timelessDate = TimelessDate(year: 0, month: 0, day: 0)
        let result = timelessDate.formEncodableValue()
        #expect(!result.isEmpty)
    }

    // MARK: - Comparable Tests

    @Test func lessThan() {
        let date1 = TimelessDate(year: 2024, month: 1, day: 1)
        let date2 = TimelessDate(year: 2024, month: 6, day: 1)
        #expect(date1 < date2)
    }

    @Test func greaterThan() {
        let date1 = TimelessDate(year: 2024, month: 12, day: 31)
        let date2 = TimelessDate(year: 2024, month: 1, day: 1)
        #expect(date1 > date2)
    }

    @Test func lessThanDifferentYears() {
        let date1 = TimelessDate(year: 2023, month: 12, day: 31)
        let date2 = TimelessDate(year: 2024, month: 1, day: 1)
        #expect(date1 < date2)
    }

    // MARK: - Equatable Tests

    @Test func equalTo() {
        let date1 = TimelessDate(year: 2024, month: 6, day: 15)
        let date2 = TimelessDate(year: 2024, month: 6, day: 15)
        #expect(date1 == date2)
    }

    @Test func notEqualTo() {
        let date1 = TimelessDate(year: 2024, month: 6, day: 15)
        let date2 = TimelessDate(year: 2024, month: 6, day: 16)
        #expect(date1 != date2)
    }

    // MARK: - Codable Tests

    @Test func encodeAndDecode() throws {
        let timelessDate = TimelessDate(year: 2024, month: 6, day: 15)
        let encoder = JSONEncoder()
        let data = try encoder.encode(timelessDate)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TimelessDate.self, from: data)

        #expect(decoded.year == 2024)
        #expect(decoded.month == 6)
        #expect(decoded.day == 15)
    }

    @Test func decodeFromValidString() throws {
        let json = Data(#""2024-06-15""#.utf8)
        let decoder = JSONDecoder()
        let date = try decoder.decode(TimelessDate.self, from: json)

        #expect(date.year == 2024)
        #expect(date.month == 6)
        #expect(date.day == 15)
    }

    @Test func decodeFromInvalidStringThrows() {
        let json = Data(#""invalid""#.utf8)
        let decoder = JSONDecoder()

        do {
            _ = try decoder.decode(TimelessDate.self, from: json)
            Issue.record("Should have thrown")
        } catch {
            // Expected
        }
    }

    // MARK: - Static Properties Tests

    @Test func monotonic() {
        let date = TimelessDate.monotonic
        #expect(date.year > 0)
        #expect(date.month >= 1 && date.month <= 12)
        #expect(date.day >= 1 && date.day <= 31)
    }

    @Test func monotonicWithTimeZone() {
        let date = TimelessDate.monotonic(.gmt)
        #expect(date.year > 0)
    }

    @Test func distantPast() {
        let date = TimelessDate.distantPast
        // Just verify it returns something
        #expect(date.year > 0 || date.year == 0)
    }

    @Test func distantFuture() {
        let date = TimelessDate.distantFuture
        #expect(date.year > 2000)
    }

    // MARK: - Date Extension Tests

    @Test func dateAsTimelessDate() {
        let date = Date(timeIntervalSince1970: 1_718_409_600) // 2024-06-15 00:00:00 UTC
        let timeless = date.asTimelessDate(.gmt)
        #expect(timeless.year == 2024)
        #expect(timeless.month == 6)
        #expect(timeless.day == 15)
    }

    // MARK: - Hashable Tests

    @Test func hashable() {
        let date1 = TimelessDate(year: 2024, month: 6, day: 15)
        let date2 = TimelessDate(year: 2024, month: 6, day: 15)
        var set = Set<TimelessDate>()
        set.insert(date1)
        set.insert(date2)
        #expect(set.count == 1)
    }

    // MARK: - Interval Tests

    @Test func intervalWithValidTimes() {
        let timelessDate = TimelessDate(year: 2024, month: 6, day: 15)
        let startTime = Time(hours: 9, minutes: 0, seconds: 0)
        let endTime = Time(hours: 17, minutes: 0, seconds: 0)

        let interval = timelessDate.interval(start: startTime, end: endTime, calendar: RoundTripTestSupport.gregorianUTC, timeZone: .gmt)

        #expect(interval != nil)
        #expect(interval?.duration == 8 * 3600.0) // 8 hours in seconds
    }

    @Test func intervalWithEndBeforeStart() {
        let timelessDate = TimelessDate(year: 2024, month: 6, day: 15)
        let startTime = Time(hours: 22, minutes: 0, seconds: 0)
        let endTime = Time(hours: 6, minutes: 0, seconds: 0) // Next day

        let interval = timelessDate.interval(start: startTime, end: endTime, calendar: RoundTripTestSupport.gregorianUTC, timeZone: .gmt)

        #expect(interval != nil)
    }

    @Test func intervalWithSameStartAndEnd() {
        let timelessDate = TimelessDate(year: 2024, month: 6, day: 15)
        let time = Time(hours: 12, minutes: 0, seconds: 0)

        let interval = timelessDate.interval(start: time, end: time, calendar: RoundTripTestSupport.gregorianUTC, timeZone: .gmt)

        #expect(interval != nil)
        #expect(interval?.duration == 0.0)
    }
}
