import Foundation

/// A time structure that allows to exchange time-only
public struct Time: Equatable, Hashable, Sendable {

    /// The hour of the time
    public let hours: UInt

    /// The minute of the time
    public let minutes: UInt

    /// The second of the time
    public let seconds: UInt

    /// Initializer
    /// - parameter hours: The number of hours
    /// - parameter minutes: The number of minutes
    /// - parameter seconds: The number of seconds
    public init(hours: UInt, minutes: UInt, seconds: UInt) {
        self.hours = (0 ..< 24).contains(hours) ? hours : 23
        self.minutes = (0 ..< 60).contains(minutes) ? minutes : 59
        self.seconds = (0 ..< 60).contains(seconds) ? seconds : 59
    }
}

// MARK: - Operators
public extension Time {

    static func + (lhs: Time, rhs: TimeInterval) -> Time {
        .init(interval: lhs.timeInterval + rhs)
    }

    static func - (lhs: Time, rhs: TimeInterval) -> Time {
        .init(interval: lhs.timeInterval - rhs)
    }

    static func + (lhs: Time, rhs: Time) -> Time {
        .init(interval: lhs.timeInterval + rhs.timeInterval)
    }

    static func - (lhs: Time, rhs: Time) -> Time {
        .init(interval: max(0, lhs.timeInterval - rhs.timeInterval))
    }
}

// MARK: - TimeInterval
public extension Time {

    /// Initialize from a time interval
    init(interval: TimeInterval) {
        let components = RoundTripSupport.posixCalendar.dateComponents([.hour, .minute, .second], from: Date(timeIntervalSince1970: interval))
        hours = UInt(components.hour ?? 0)
        minutes = UInt(components.minute ?? 0)
        seconds = UInt(components.second ?? 0)
    }

    /// Return as a time interval
    var timeInterval: TimeInterval {
        (3600.0 * TimeInterval(hours))
            + (60.0 * TimeInterval(minutes))
            + TimeInterval(seconds)
    }
}

// MARK: - Utilities
public extension Time {

    /// Return with time as a date object
    func asDate(timeZone: TimeZone) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar.date(
            bySettingHour: Int(hours),
            minute: Int(minutes),
            second: Int(seconds),
            of: Date.monotonic
        )
    }
}

// MARK: - FormEncodable
extension Time: FormEncodable {

    /// Return with time as a string
    public var asString: String? {
        guard let date = asDate(timeZone: .gmt) else {
            return nil
        }
        return RoundTripSupport.isoTimeFormatter.string(from: date)
    }

    public func formEncodableValue() -> String {
        asString ?? "00:00:00"
    }
}

// MARK: - Comparable
extension Time: Comparable {
    public static func < (lhs: Time, rhs: Time) -> Bool {
        lhs.timeInterval < rhs.timeInterval
    }
}

// MARK: - Codable
extension Time: Codable {

    /// Initializer for Codable
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        guard let value = RoundTripSupport.isoTimeFormatter.date(from: value) else {
            throw CocoaError(.coderInvalidValue)
        }

        let components = RoundTripSupport.posixCalendar.dateComponents([.hour, .minute, .second], from: value)
        hours = UInt(components.hour ?? 0)
        minutes = UInt(components.minute ?? 0)
        seconds = UInt(components.second ?? 0)
    }

    /// Encode
    public func encode(to encoder: any Encoder) throws {
        guard let date = RoundTripSupport.posixCalendar.date(bySettingHour: Int(hours), minute: Int(minutes), second: Int(seconds), of: Date.monotonic) else {
            throw CocoaError(.coderInvalidValue)
        }
        var container = encoder.singleValueContainer()
        let time = RoundTripSupport.isoTimeFormatter.string(from: date)
        try container.encode(time)
    }
}

public extension Date {

    func asTime(_ timeZone: TimeZone) -> Time {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let hours = UInt(calendar.component(.hour, from: self))
        let minutes = UInt(calendar.component(.minute, from: self))
        let seconds = UInt(calendar.component(.second, from: self))
        return .init(hours: hours, minutes: minutes, seconds: seconds)
    }
}

public extension Time {

    static var monotonic: Time {
        .monotonic()
    }

    static var startOfDay: Time {
        .init(hours: 0, minutes: 0, seconds: 0)
    }

    static var noon: Time {
        .init(hours: 12, minutes: 00, seconds: 00)
    }

    static var endOfDay: Time {
        .init(hours: 23, minutes: 59, seconds: 59)
    }

    static func monotonic(tz: TimeZone = .gmt) -> Time {
        Date.monotonic.asTime(tz)
    }

}
