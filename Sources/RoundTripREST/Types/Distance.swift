import Foundation

/// A distance value that accepts either a JSON number or a numeric string.
public struct Distance: Codable, Hashable, Sendable, ExpressibleByFloatLiteral {

    /// The decoded distance, or `nil` when the source value is not numeric.
    public var value: Double?

    /// Creates a distance from a floating-point literal.
    public init(floatLiteral value: Double) {
        self.value = value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let d = try? container.decode(Double.self) {
            value = d
        } else if let s = try? container.decode(String.self), let d = Double(s) {
            value = d
        } else {
            value = nil
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
