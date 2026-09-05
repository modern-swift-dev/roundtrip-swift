import Foundation

/// A timeless date structure that allows to exchange date-only
public struct TimelessDate: Hashable, Sendable {

    /// The year of the date
    public let year: UInt

    /// The month of the date
    public let month: UInt

    /// The day of the date
    public let day: UInt

    /// Initializer
    /// - parameter year: The number of year
    /// - parameter month: The number of month
    /// - parameter day: The number of day
    public init(year: UInt, month: UInt, day: UInt) {
        self.year = min(9999, year)
        self.month = month
        self.day = day
    }
}

// MARK: - Utilities
public extension TimelessDate {
    /// Return with timeless date as a date object
    var asDate: Date? {
        asDate(timeZone: .gmt)
    }

    /// Return with timeless date as a date object
    func asDate(timeZone: TimeZone) -> Date? {
        var calendar = RoundTripSupport.posixCalendar
        calendar.timeZone = timeZone
        let components = DateComponents(timeZone: timeZone, year: Int(year), month: Int(month), day: Int(day))
        return calendar.date(from: components)
    }
}

// MARK: - FormEncodable
extension TimelessDate: FormEncodable {

    /// Return with timeless date as a string
    public var asString: String? {
        guard let date = asDate else {
            return nil
        }
        return RoundTripSupport.isoDateFormatter.string(from: date)
    }

    public func formEncodableValue() -> String {
        asString ?? "0001-01-01"
    }
}

// MARK: - Comparable
extension TimelessDate: Comparable {
    public static func < (lhs: TimelessDate, rhs: TimelessDate) -> Bool {
        lhs.asDate?.timeIntervalSinceReferenceDate ?? 0 < rhs.asDate?.timeIntervalSinceReferenceDate ?? 0
    }
}

// MARK: - Equatable
extension TimelessDate: Equatable {
    public static func == (lhs: TimelessDate, rhs: TimelessDate) -> Bool {
        lhs.asDate?.timeIntervalSinceReferenceDate ?? 0 == rhs.asDate?.timeIntervalSinceReferenceDate ?? 0
    }
}

// MARK: - Hashable
public extension TimelessDate {
    func hash(into hasher: inout Hasher) {
        hasher.combine(asDate?.timeIntervalSinceReferenceDate ?? 0)
    }
}

// MARK: - Codable
extension TimelessDate: Codable {

    /// Initializer for Codable
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        guard let value = RoundTripSupport.isoDateFormatter.date(from: value) else {
            throw CocoaError(.coderInvalidValue)
        }

        let calendar = RoundTripSupport.posixCalendar
        let components = calendar.dateComponents([.year, .month, .day], from: value)
        year = UInt(components.year ?? 1)
        month = UInt(components.month ?? 1)
        day = UInt(components.day ?? 1)
    }

    /// Encode
    public func encode(to encoder: any Encoder) throws {
        let calendar = RoundTripSupport.posixCalendar

        let components = DateComponents(timeZone: .gmt, year: Int(year), month: Int(month), day: Int(day))

        guard let date = calendar.date(from: components) else {
            throw CocoaError(.coderInvalidValue)
        }
        var container = encoder.singleValueContainer()
        let time = RoundTripSupport.isoDateFormatter.string(from: date)
        try container.encode(time)
    }
}

public extension Date {

    /// Return the date part of the date
    /// - parameter: The TimeZone to use
    /// - returns: The TimelessDate Object
    func asTimelessDate(_ timeZone: TimeZone) -> TimelessDate {
        var calendar = RoundTripSupport.posixCalendar
        calendar.timeZone = timeZone
        let year = UInt(calendar.component(.year, from: self))
        let month = UInt(calendar.component(.month, from: self))
        let day = UInt(calendar.component(.day, from: self))
        return .init(year: year, month: month, day: day)
    }
}

public extension TimelessDate {

    static var monotonic: TimelessDate {
        .monotonic()
    }

    static var distantPast: TimelessDate {
        Date.distantPast.asTimelessDate(.gmt)
    }

    static var distantFuture: TimelessDate {
        Date.distantFuture.asTimelessDate(.gmt)
    }

    static func monotonic(_ tz: TimeZone = .gmt) -> TimelessDate {
        Date.monotonic.asTimelessDate(tz)
    }

    func interval(
        start: Time,
        end: Time,
        calendar: Calendar = Calendar(identifier: .gregorian),
        timeZone: TimeZone = .gmt,
        disallowFutureInterval: Bool = false
    ) -> DateInterval? {
        var startComponents = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: Int(year),
            month: Int(month),
            day: Int(day),
            hour: Int(start.hours),
            minute: Int(start.minutes),
            second: Int(start.seconds)
        )

        var endComponents = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: Int(year),
            month: Int(month),
            day: Int(end >= start ? day : day + 1),
            hour: Int(end.hours),
            minute: Int(end.minutes),
            second: Int(end.seconds)
        )

        if disallowFutureInterval, let start = startComponents.date, start > Date.monotonic {
            startComponents.day = (startComponents.day ?? 0) - 1
            endComponents.day = (endComponents.day ?? 0) - 1
        }

        guard let startDate = startComponents.date, let endDate = endComponents.date else {
            return nil
        }
        return .init(start: startDate, end: endDate)
    }
}
