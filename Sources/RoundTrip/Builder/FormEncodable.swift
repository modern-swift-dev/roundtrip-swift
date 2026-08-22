import Foundation

// MARK: - Protocol
public protocol FormEncodable: Sendable {

    /// Serialize to form encoded
    func formEncodableValue() -> String
}

// MARK: - String
extension String: FormEncodable {
    public func formEncodableValue() -> String {
        self
    }
}

// MARK: - Integer
extension Int: FormEncodable {
    public func formEncodableValue() -> String {
        "\(self)"
    }
}

extension Int8: FormEncodable {
    public func formEncodableValue() -> String {
        "\(self)"
    }
}

extension Int16: FormEncodable {
    public func formEncodableValue() -> String {
        "\(self)"
    }
}

extension Int32: FormEncodable {
    public func formEncodableValue() -> String {
        "\(self)"
    }
}

extension Int64: FormEncodable {
    public func formEncodableValue() -> String {
        "\(self)"
    }
}

extension UInt: FormEncodable {
    public func formEncodableValue() -> String {
        "\(self)"
    }
}

extension UInt8: FormEncodable {
    public func formEncodableValue() -> String {
        "\(self)"
    }
}

extension UInt16: FormEncodable {
    public func formEncodableValue() -> String {
        "\(self)"
    }
}

extension UInt32: FormEncodable {
    public func formEncodableValue() -> String {
        "\(self)"
    }
}

extension UInt64: FormEncodable {
    public func formEncodableValue() -> String {
        "\(self)"
    }
}

// MARK: - Double / Floats
extension NumberFormatter {
    static let httpFormEncoded: NumberFormatter = {
        let format = NumberFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.numberStyle = .decimal
        format.decimalSeparator = "."
        format.minimumIntegerDigits = 1
        format.minimumFractionDigits = 0
        return format
    }()
}

extension Float: FormEncodable {
    public func formEncodableValue() -> String {
        guard let value = NumberFormatter.httpFormEncoded.string(from: NSNumber(value: self)) else {
            return "NaN"
        }
        return value
    }
}

extension Double: FormEncodable {
    public func formEncodableValue() -> String {
        guard let value = NumberFormatter.httpFormEncoded.string(from: NSNumber(value: self)) else {
            return "NaN"
        }
        return value
    }
}

// MARK: - Bool
extension Bool: FormEncodable {

    public func formEncodableValue() -> String {
        self ? "true" : "false"
    }
}

// MARK: - Data
extension Data: FormEncodable {

    public func formEncodableValue() -> String {
        base64EncodedString()
    }
}

// MARK: - Date
extension Date: FormEncodable {
    public func formEncodableValue() -> String {
        ISO8601Format(.iso8601(timeZone: .gmt))
    }
}
