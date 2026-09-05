import Foundation
import RoundTrip
import Testing

struct DateTimeConversionTests {
    @Test func concurrentDateAndTimeConversions() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0 ..< 64 {
                group.addTask {
                    let date = TimelessDate(year: 2024, month: UInt(index % 12 + 1), day: UInt(index % 28 + 1))
                    let time = Time(hours: UInt(index % 24), minutes: UInt(index % 60), seconds: UInt((index * 7) % 60))
                    let encoder = JSONEncoder()
                    let decoder = JSONDecoder()
                    for _ in 0 ..< 8 {
                        let encodedDate = try encoder.encode(date)
                        let encodedTime = try encoder.encode(time)
                        #expect(try decoder.decode(TimelessDate.self, from: encodedDate) == date)
                        #expect(try decoder.decode(Time.self, from: encodedTime) == time)
                        #expect(try decoder.decode(String.self, from: encodedDate) == date.asString)
                        #expect(try decoder.decode(String.self, from: encodedTime) == time.asString)
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    @Test func timeZoneConversionDoesNotChangeUTCDefaults() throws {
        let east = try #require(TimeZone(secondsFromGMT: 9 * 3600))
        let west = try #require(TimeZone(secondsFromGMT: -7 * 3600))
        let instant = Date(timeIntervalSince1970: 0)
        #expect(instant.asTime(east) == Time(hours: 9, minutes: 0, seconds: 0))
        #expect(instant.asTime(west) == Time(hours: 17, minutes: 0, seconds: 0))
        #expect(instant.asTime(.gmt) == .startOfDay)
        #expect(instant.asTimelessDate(west) == TimelessDate(year: 1969, month: 12, day: 31))
        #expect(instant.asTimelessDate(.gmt) == TimelessDate(year: 1970, month: 1, day: 1))
        #expect(TimelessDate(year: 1970, month: 1, day: 1).asString == "1970-01-01")
        #expect(Time.startOfDay.asString == "00:00:00")
    }
}
