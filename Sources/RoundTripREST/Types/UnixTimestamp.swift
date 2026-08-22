import Foundation
import RoundTrip

/// A Unix timestamp stored as milliseconds since 1970.
public struct UnixTimestamp: Codable, Sendable {
    /// The timestamp in milliseconds since 1970.
    public var value: Int64

    /// The corresponding date.
    public var date: Date {
        Date(timeIntervalSince1970: Double(value) / 1000)
    }

    /// Creates a timestamp from milliseconds since 1970.
    public init(value: Int64) {
        self.value = value
    }

    /// Creates a timestamp from a date.
    public init(value: Date) {
        self.value = Int64(value.timeIntervalSince1970 * 1000.0)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(Int64.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value)
    }

    /// The current network-adjusted timestamp when available.
    public static var now: UnixTimestamp {
        .init(value: Date.monotonic)
    }
}
