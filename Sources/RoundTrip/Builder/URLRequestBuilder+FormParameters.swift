import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public extension URLRequestBuilder {

    /// Set the a Multi-Form Encoded payload
    /// - parameter parameters: The form to encode
    /// - returns: `self`
    func setBody(formEncoded parameters: [FormParameter]) -> Self {
        guard !parameters.isEmpty, let data = parameters.toBody() else {
            return self
        }
        body = data
        _ = addHeader(.contentType(.formEncoded))
        _ = addHeader(.contentLength(UInt64(data.count)))
        return self
    }
}

// MARK: - Form Parameters Body
public extension URLRequestBuilder {

    /// A form parameter
    struct FormParameter {

        /// The Name
        public let name: String

        /// The Value
        public let value: any FormEncodable

        /// The Initializer
        public init(name: String, value: any FormEncodable) {
            self.name = name
            self.value = value
        }

        var debugDescription: String {
            "\(name)=\(value)"
        }
    }
}

public extension URLRequestBuilder.FormParameter {

    /// Create a URLQueryItem
    func toItem() -> URLQueryItem {
        URLQueryItem(name: name, value: value.formEncodableValue())
    }
}

public extension [URLRequestBuilder.FormParameter] {

    /// Map the array of form parameter into a
    func toItems() -> [URLQueryItem] {
        map { $0.toItem() }
    }

    /// Map the form parameters into a Data for Form-Encoded Body
    func toBody() -> Data? {
        guard !isEmpty else {
            return nil
        }
        var components = URLComponents()
        components.queryItems = toItems()
        return components.percentEncodedQuery?.data(using: .utf8)
    }
}
