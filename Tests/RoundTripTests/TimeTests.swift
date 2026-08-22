import Foundation
import RoundTrip
import Testing

@Suite(.serialized) struct TimeTests {

    // MARK: - Initialization Tests

    @Test func initWithValidValues() {
        let time = Time(hours: 10, minutes: 30, seconds: 45)
        #expect(time.hours == 10)
        #expect(time.minutes == 30)
        #expect(time.seconds == 45)
    }

    @Test func initClampsHours() {
        let time = Time(hours: 25, minutes: 30, seconds: 45)
        #expect(time.hours == 23)
    }

    @Test func initClampsMinutes() {
        let time = Time(hours: 10, minutes: 60, seconds: 45)
        #expect(time.minutes == 59)
    }

    @Test func initClampsSeconds() {
        let time = Time(hours: 10, minutes: 30, seconds: 60)
        #expect(time.seconds == 59)
    }

    @Test func initWithZeros() {
        let time = Time(hours: 0, minutes: 0, seconds: 0)
        #expect(time.hours == 0)
        #expect(time.minutes == 0)
        #expect(time.seconds == 0)
    }

    // MARK: - TimeInterval Initialization Tests

    @Test func initFromTimeInterval() {
        // 1 hour, 30 minutes, 45 seconds = 5445 seconds
        let interval: TimeInterval = 5445
        let time = Time(interval: interval)
        #expect(time.hours == 1)
        #expect(time.minutes == 30)
        #expect(time.seconds == 45)
    }

    @Test func initFromZeroTimeInterval() {
        let time = Time(interval: 0)
        #expect(time.hours == 0)
        #expect(time.minutes == 0)
        #expect(time.seconds == 0)
    }

    // MARK: - TimeInterval Property Tests

    @Test func timeInterval() {
        let time = Time(hours: 1, minutes: 30, seconds: 45)
        // 1*3600 + 30*60 + 45 = 5445
        #expect(time.timeInterval == 5445)
    }

    @Test func timeIntervalZero() {
        let time = Time(hours: 0, minutes: 0, seconds: 0)
        #expect(time.timeInterval == 0)
    }

    // MARK: - Operator Tests

    @Test func addTimeInterval() {
        let time = Time(hours: 1, minutes: 0, seconds: 0)
        let result = time + 3600.0 // Add 1 hour
        #expect(result.hours == 2)
    }

    @Test func subtractTimeInterval() {
        let time = Time(hours: 2, minutes: 0, seconds: 0)
        let result = time - 3600.0 // Subtract 1 hour
        #expect(result.hours == 1)
    }

    @Test func addTime() {
        let time1 = Time(hours: 1, minutes: 20, seconds: 0)
        let time2 = Time(hours: 0, minutes: 30, seconds: 0)
        let result = time1 + time2
        // Time + Time doesn't handle overflow, minutes are clamped to valid range
        #expect(result.hours == 1)
        #expect(result.minutes == 50)
    }

    @Test func subtractTime() {
        let time1 = Time(hours: 2, minutes: 30, seconds: 0)
        let time2 = Time(hours: 1, minutes: 0, seconds: 0)
        let result = time1 - time2
        #expect(result.hours == 1)
        #expect(result.minutes == 30)
    }

    // MARK: - Comparable Tests

    @Test func lessThan() {
        let time1 = Time(hours: 1, minutes: 0, seconds: 0)
        let time2 = Time(hours: 2, minutes: 0, seconds: 0)
        #expect(time1 < time2)
    }

    @Test func greaterThan() {
        let time1 = Time(hours: 2, minutes: 0, seconds: 0)
        let time2 = Time(hours: 1, minutes: 0, seconds: 0)
        #expect(time1 > time2)
    }

    @Test func equalTo() {
        let time1 = Time(hours: 1, minutes: 30, seconds: 45)
        let time2 = Time(hours: 1, minutes: 30, seconds: 45)
        #expect(time1 == time2)
    }

    // MARK: - FormEncodable Tests

    @Test func formEncodableValue() {
        let time = Time(hours: 10, minutes: 30, seconds: 45)
        let result = time.formEncodableValue()
        #expect(result.contains("10") || result.contains("30") || result.contains("45"))
    }

    @Test func asString() {
        let time = Time(hours: 10, minutes: 30, seconds: 45)
        let result = time.asString
        #expect(result != nil)
    }

    // MARK: - Codable Tests

    @Test func encodeAndDecode() throws {
        let time = Time(hours: 14, minutes: 30, seconds: 0)
        let encoder = JSONEncoder()
        let data = try encoder.encode(time)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Time.self, from: data)

        #expect(decoded.hours == 14)
        #expect(decoded.minutes == 30)
        #expect(decoded.seconds == 0)
    }

    @Test func decodeFromValidString() throws {
        let json = Data(#""14:30:00""#.utf8)
        let decoder = JSONDecoder()
        let time = try decoder.decode(Time.self, from: json)

        #expect(time.hours == 14)
        #expect(time.minutes == 30)
        #expect(time.seconds == 0)
    }

    @Test func decodeFromInvalidStringThrows() throws {
        let json = Data(#""invalid""#.utf8)
        let decoder = JSONDecoder()

        do {
            _ = try decoder.decode(Time.self, from: json)
            Issue.record("Should have thrown")
        } catch {
            // Expected
        }
    }

    // MARK: - asDate Tests

    @Test func asDateWithUTC() {
        let time = Time(hours: 12, minutes: 0, seconds: 0)
        let date = time.asDate(timeZone: .gmt)
        #expect(date != nil)
    }

    // MARK: - Static Properties Tests

    @Test func startOfDay() {
        let time = Time.startOfDay
        #expect(time.hours == 0)
        #expect(time.minutes == 0)
        #expect(time.seconds == 0)
    }

    @Test func noon() {
        let time = Time.noon
        #expect(time.hours == 12)
        #expect(time.minutes == 0)
        #expect(time.seconds == 0)
    }

    @Test func endOfDay() {
        let time = Time.endOfDay
        #expect(time.hours == 23)
        #expect(time.minutes == 59)
        #expect(time.seconds == 59)
    }

    @Test func monotonic() {
        let time = Time.monotonic
        // Just verify it doesn't crash and returns valid values
        #expect(time.hours <= 23)
        #expect(time.minutes <= 59)
        #expect(time.seconds <= 59)
    }

    @Test func monotonicWithTimeZone() {
        let time = Time.monotonic(tz: .gmt)
        #expect(time.hours <= 23)
    }

    // MARK: - Date Extension Tests

    @Test func dateAsTime() {
        let date = Date(timeIntervalSince1970: 43200) // 12:00:00 UTC
        let time = date.asTime(.gmt)
        #expect(time.hours == 12)
        #expect(time.minutes == 0)
        #expect(time.seconds == 0)
    }

    // MARK: - Hashable Tests

    @Test func hashable() {
        let time1 = Time(hours: 10, minutes: 30, seconds: 45)
        let time2 = Time(hours: 10, minutes: 30, seconds: 45)
        var set = Set<Time>()
        set.insert(time1)
        set.insert(time2)
        #expect(set.count == 1)
    }
}
