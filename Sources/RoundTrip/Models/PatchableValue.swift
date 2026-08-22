/// A dynamic enum meant to allow PATCH http calls
///
public enum PatchableValue<T: Codable & Sendable>: Codable, Sendable {

    /// `unmodified` means that nothing is added to the JSON
    case unmodified

    /// `modified` means that the data is added to the JSON
    case modified(T)

    /// `deleted` means that `null` is added to the JSON
    case deleted

    /// Decodes the value from JSON:
    /// - If the value is `null`, returns `.deleted`
    /// - If a value exists, returns `.modified(value)`
    /// - Note: `.unmodified` cannot be represented in JSON (key would be absent)
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .deleted
        } else {
            let value = try container.decode(T.self)
            self = .modified(value)
        }
    }

    /// Encoding method implementation that output
    /// the correct JSON.
    public func encode(to encoder: any Encoder) throws {
        switch self {
            case .unmodified:
                break
            case .deleted:
                var container = encoder.singleValueContainer()
                try container.encodeNil()
            case let .modified(value):
                try value.encode(to: encoder)
        }
    }

    /// Return the actual value. May be nil
    public var value: T? {
        if case let Self.modified(value) = self {
            return value
        }
        return nil
    }

    /// Update the value
    public static func update(value: T?) -> PatchableValue<T> {
        if let value {
            return .modified(value)
        }
        return .deleted
    }

    /// Check if unmodified
    public var isUnmodified: Bool {
        if case Self.unmodified = self {
            return true
        }
        return false
    }
}
