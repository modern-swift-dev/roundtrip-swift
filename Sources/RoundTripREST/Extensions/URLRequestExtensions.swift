import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import RoundTrip

/// Extensions for URLRequest to simplify common REST operations.
/// Provides fluent interface for configuring requests.
public extension URLRequest {

    /// Initialize with URL and query parameters
    /// - Parameters:
    ///   - url: Base URL for request
    ///   - queryParams: Optional query parameters to append
    /// - Throws: URLError if URL creation fails
    init(
        url: URL,
        queryParams: [String: any FormEncodable]?
    ) throws {
        try self.init(url: URLComponents.create(url: url, queryParams: queryParams))
    }

    /// Initialize with base URL, path and query parameters
    /// - Parameters:
    ///   - baseUrl: Base URL for request
    ///   - path: Path to append to base URL
    ///   - queryParams: Optional query parameters to append
    /// - Throws: URLError if URL creation fails
    init(
        baseUrl: URL,
        path: String,
        queryParams: [String: any FormEncodable]?
    ) throws {
        try self.init(url: URLComponents.create(baseUrl: baseUrl, path: path, queryParams: queryParams))
    }

    /// Add HTTP header to request
    /// - Parameters:
    ///   - value: Header value
    ///   - name: Header name
    mutating func addHeader(_ value: String?, name: String) {
        setValue(value, forHTTPHeaderField: name)
    }

    /// Add encodable body to request
    /// - Parameters:
    ///   - value: Encodable value to use as body
    ///   - encoder: JSONEncoder to use
    /// - Returns: Self for chaining
    /// - Throws: Encoding error if body cannot be encoded
    @discardableResult mutating func codableBody(_ value: some Encodable, encoder: JSONEncoder) throws -> Self {
        httpBody = try encoder.encode(value)
        return self
    }

    /// Set method to POST
    /// - Returns: Self for chaining
    @discardableResult mutating func post() -> Self {
        httpMethod = "POST"
        return self
    }

    /// Set method to PUT
    /// - Returns: Self for chaining
    @discardableResult mutating func put() -> Self {
        httpMethod = "PUT"
        return self
    }

    /// Set method to DELETE
    /// - Returns: Self for chaining
    @discardableResult mutating func delete() -> Self {
        httpMethod = "DELETE"
        return self
    }

    /// Set method to PATCH
    /// - Returns: Self for chaining
    @discardableResult mutating func patch() -> Self {
        httpMethod = "PATCH"
        return self
    }

    /// Set method to GET
    /// - Returns: Self for chaining
    @discardableResult mutating func get() -> Self {
        httpMethod = "GET"
        return self
    }

    /// Set Accept header to application/json
    /// - Returns: Self for chaining
    @discardableResult mutating func acceptJson() -> Self {
        accept(mimeType: "application/json")
    }

    /// Set Accept header
    /// - Parameter mimeType: MIME type to accept
    /// - Returns: Self for chaining
    @discardableResult mutating func accept(mimeType: String) -> Self {
        addHeader(mimeType, name: "Accept")
        return self
    }

    /// Set Authorization header
    /// - Parameter value: Authorization value
    /// - Returns: Self for chaining
    @discardableResult mutating func authorization(_ value: String) -> Self {
        addHeader(value, name: "Authorization")
        return self
    }

    /// Set Bearer token Authorization header
    /// - Parameter value: Token value
    /// - Returns: Self for chaining
    @discardableResult mutating func bearerTokenAuthorization(_ value: String) -> Self {
        addHeader("Bearer \(value)", name: "Authorization")
        return self
    }

    /// Set Content-Type to application/json
    /// - Returns: Self for chaining
    @discardableResult mutating func contentJson() -> Self {
        contentType(mimeType: "application/json")
        return self
    }

    /// Set Content-Type header
    /// - Parameter mimeType: MIME type for content
    /// - Returns: Self for chaining
    @discardableResult mutating func contentType(mimeType: String) -> Self {
        addHeader(mimeType, name: "Content-Type")
        return self
    }

    /// Set Accept header to application/json, set method to GET and add Authorization header if provided
    /// - Parameters:
    ///   - authorizations: Optional authorization value
    ///   - isBearerToken: Whether the authorization value is a Bearer token
    /// - Returns: Self for chaining
    @discardableResult mutating func getJson(authorizations: String? = nil, isBearerToken: Bool = false) -> Self {
        get()
        acceptJson()
        if let authorizations {
            if isBearerToken {
                bearerTokenAuthorization(authorizations)
            } else {
                authorization(authorizations)
            }
        }
        return self
    }

    /// Set method to POST, set Accept header to application/json, add Authorization header if provided and set Content-Type to application/json
    /// - Parameters:
    ///   - authorizations: Optional authorization value
    ///   - body: Encodable body to use
    ///   - encoder: JSONEncoder to use
    ///   - isBearerToken: Whether the authorization value is a Bearer token
    /// - Returns: Self for chaining
    /// - Throws: Encoding error if body cannot be encoded
    @discardableResult mutating func postJson(authorizations: String? = nil, body: some Encodable, encoder: JSONEncoder, isBearerToken: Bool = false) throws -> Self {
        post()
        acceptJson()
        contentJson()
        if let authorizations {
            if isBearerToken {
                bearerTokenAuthorization(authorizations)
            } else {
                authorization(authorizations)
            }
        }
        try codableBody(body, encoder: encoder)
        return self
    }

    /// Set method to PUT, set Accept header to application/json, add Authorization header if provided and set Content-Type to application/json
    /// - Parameters:
    ///   - authorizations: Optional authorization value
    ///   - body: Encodable body to use
    ///   - encoder: JSONEncoder to use
    ///   - isBearerToken: Whether the authorization value is a Bearer token
    /// - Returns: Self for chaining
    /// - Throws: Encoding error if body cannot be encoded
    @discardableResult mutating func putJson(authorizations: String? = nil, body: some Encodable, encoder: JSONEncoder, isBearerToken: Bool = false) throws -> Self {
        put()
        acceptJson()
        contentJson()
        if let authorizations {
            if isBearerToken {
                bearerTokenAuthorization(authorizations)
            } else {
                authorization(authorizations)
            }
        }
        try codableBody(body, encoder: encoder)
        return self
    }

    /// Set method to DELETE, set Accept header to application/json and add Authorization header if provided
    /// - Parameters:
    ///   - authorizations: Optional authorization value
    ///   - isBearerToken: Whether the authorization value is a Bearer token
    /// - Returns: Self for chaining
    @discardableResult mutating func deleteJson(authorizations: String? = nil, isBearerToken: Bool = false) -> Self {
        delete()
        acceptJson()
        if let authorizations {
            if isBearerToken {
                bearerTokenAuthorization(authorizations)
            } else {
                authorization(authorizations)
            }
        }
        return self
    }

    /// Set method to POST, set Accept header to application/json, add Authorization header if provided and set Content-Type to multipart/form-data
    /// - Parameters:
    ///   - authorizations: Optional authorization value
    ///   - body: MultipartBody to use
    ///   - isBearerToken: Whether the authorization value is a Bearer token
    /// - Returns: Self for chaining
    /// - Throws: Encoding error if body cannot be encoded
    @discardableResult mutating func postMultipart(authorizations: String? = nil, body: MultipartBody, isBearerToken: Bool = false) throws -> Self {
        post()
        acceptJson()
        if let authorizations {
            if isBearerToken {
                bearerTokenAuthorization(authorizations)
            } else {
                authorization(authorizations)
            }
        }
        addHeader(body.contentType, name: "Content-Type")
        if let size = body.size {
            addHeader("\(size)", name: "Content-Length")
        }
        return self
    }

}

/// Extensions for URLComponents to handle query parameters
public extension URLComponents {
    /// Creates URL with query parameters
    /// - Parameters:
    ///   - baseUrl: The base URL
    ///   - path: Path to append
    ///   - queryParams: Optional query parameters
    /// - Returns: URL with query parameters
    /// - Throws: URLError if URL creation fails
    static func create(baseUrl: URL, path: String, queryParams: [String: any FormEncodable]? = nil) throws -> URL {
        guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: true) else {
            throw URLError(.badURL)
        }
        components.path = path

        if let queryParams, !queryParams.isEmpty {
            components.percentEncodedQueryItems = queryParams
                .sorted(by: { $0.key < $1.key })
                .map {
                    URLQueryItem(
                        name: $0.addingPercentEncoding(withAllowedCharacters: .improvedQueryAllowed) ?? $0,
                        value: $1.formEncodableValue().addingPercentEncoding(withAllowedCharacters: .improvedQueryAllowed)
                    )
                }
        }

        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    /// Creates URL with query parameters
    /// - Parameters:
    ///   - url: Base URL
    ///   - queryParams: Optional query parameters to append
    /// - Returns: URL with query parameters
    /// - Throws: URLError if URL creation fails
    static func create(url: URL, queryParams: [String: any FormEncodable]? = nil) throws -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw URLError(.badURL)
        }

        if let queryParams, !queryParams.isEmpty {
            var existingParams = components.percentEncodedQueryItems ?? []
            existingParams.append(
                contentsOf: queryParams.sorted(by: { $0.key < $1.key })
                    .map {
                        URLQueryItem(
                            name: $0.addingPercentEncoding(withAllowedCharacters: .improvedQueryAllowed) ?? $0,
                            value: $1.formEncodableValue().addingPercentEncoding(withAllowedCharacters: .improvedQueryAllowed)
                        )
                    }
            )
            components.percentEncodedQueryItems = existingParams
        }

        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }
}
