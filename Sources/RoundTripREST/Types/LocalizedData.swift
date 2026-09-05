import Foundation

/// Generic container for localized data with type-safe language code access.
/// Supports storing and retrieving values by language code.
///
/// Example:
/// ```swift
/// var data = LocalizedData<String>()
/// data[.init("en")] = "Hello"
/// data[.init("fr")] = "Bonjour"
/// ```
public struct LocalizedData<ValueType: Codable & Sendable & Equatable>: Codable, Sendable, ExpressibleByDictionaryLiteral, Equatable {

    public typealias Key = Locale.LanguageCode
    public typealias Value = ValueType

    /// Internal storage for localized values
    private var data: [String: ValueType]

    /// Returns true if no localized values are stored
    public var isEmpty: Bool {
        data.isEmpty
    }

    /// Array of all localized values
    public var values: [ValueType] {
        Array(data.values)
    }

    /// Initialize an empty container
    public init() {
        data = [:]
    }

    /// Initialize with dictionary literal
    /// - Parameter elements: Tuples of language code and value pairs
    public init(dictionaryLiteral elements: (Locale.LanguageCode, ValueType)...) {
        data = [:]
        for (key, value) in elements {
            data[key.identifier] = value
        }
    }

    /// Initialize with dictionary
    /// - Parameter data: Dictionary of language codes to values
    public init(_ data: [Locale.LanguageCode: ValueType]) {
        self.data = [:]
        for (code, value) in data {
            self.data[code.identifier] = value
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        data = try container.decode([String: ValueType].self)
    }

    /// Access or set value for a specific language code
    public subscript(code: Locale.LanguageCode) -> ValueType? {
        get {
            data[code.identifier]
        }
        set(newValue) {
            if let newValue {
                data[code.identifier] = newValue
            } else {
                data.removeValue(forKey: code.identifier)
            }
        }
    }

    /// Array of supported language codes
    public var supportedLanguages: [Locale.LanguageCode] {
        data.keys.map { Locale.LanguageCode($0) }
    }
}
