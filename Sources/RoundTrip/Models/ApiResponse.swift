import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Represents an HTTP response including status code, headers, and body data.
/// Provides convenience methods for checking common status codes and accessing response metadata.
///
/// Example:
/// ```swift
/// let response = ApiResponse(data: responseData, response: urlResponse)
/// if response.is200 {
///     let value: MyType? = response.payloadAs(MyType.self)
/// }
/// ```
public struct ApiResponse: Sendable {

    /// The Binary Data from the `URLSessionDataTask`
    public let data: Data?

    /// Return the `statusCode` if the response is an`HTTPURLResponse`. Otherwise 0
    public let statusCode: Int

    /// The File URL Data from the `URLSessionDownloadTask`
    public let file: URL?

    /// the mime type
    public private(set) var mimeType: String?

    /// The response http headers
    public private(set) var headers: [String: any Sendable] = [:]

    /// Initializer with data and url response
    public init(data: Data?, response: URLResponse?) {
        self.data = data
        file = nil
        mimeType = response?.mimeType

        if let response = response as? HTTPURLResponse {

            for (key, value) in response.allHeaderFields {
                if let key = key as? String, let value = value as? String {
                    headers[key] = value
                }

                if let key = key as? String, let value = value as? Int {
                    headers[key] = value
                }

                if let key = key as? String, let value = value as? Date {
                    headers[key] = value
                }
            }

            statusCode = response.statusCode
        } else {
            statusCode = 0
        }
    }

    /// Initializer with data and url response
    public init(file: URL?, response: URLResponse?) {
        data = nil
        self.file = file
        mimeType = response?.mimeType

        if let response = response as? HTTPURLResponse {

            for (key, value) in response.allHeaderFields {
                if let key = key as? String, let value = value as? String {
                    headers[key] = value
                }

                if let key = key as? String, let value = value as? Int {
                    headers[key] = value
                }

                if let key = key as? String, let value = value as? Date {
                    headers[key] = value
                }
            }

            statusCode = response.statusCode
        } else {
            statusCode = 0
        }
    }

    /// Initializer for tests, and other mocking
    public init(status: UInt, data: Data? = nil, mimeType: String? = nil, headers: [String: any Sendable] = [:]) {
        self.data = data
        statusCode = Int(status)
        self.mimeType = mimeType
        self.headers = headers
        file = nil
    }

    /// Return true if the `statusCode` is `200 OK`
    public var is200: Bool {
        statusCode == 200
    }

    /// Return true if the `statusCode` is `201 Created`
    public var is201: Bool {
        statusCode == 201
    }

    /// Return true if the `statusCode` is between 200 and 299 inclusively
    public var is20x: Bool {
        (200 ..< 300).contains(statusCode)
    }

    /// Return true if the `statusCode` is `304 Not Modified`
    public var is304: Bool {
        statusCode == 304
    }

    /// Return true if the `statusCode` is `400 Bad Request`
    public var is400: Bool {
        statusCode == 400
    }

    /// Return true if the `statusCode` is `401 Unauthenticated`
    public var is401: Bool {
        statusCode == 401
    }

    /// Return true if the `statusCode` is `403 Forbidden`
    public var is403: Bool {
        statusCode == 403
    }

    /// Return true if the `statusCode` is `404 Not Found`
    public var is404: Bool {
        statusCode == 404
    }

    /// Return true if the `statusCode` is between 500 and 599 inclusively
    public var is50x: Bool {
        (500 ..< 600).contains(statusCode)
    }

    public func payloadAs<T: Decodable>(_: T.Type) -> T? {
        guard let data else {
            return nil
        }
        do {
            return try RoundTripSupport.makeJSONDecoder().decode(T.self, from: data)
        } catch {
            RoundTripSupport.log(error)
            return nil
        }
    }

    public func checkForStatusCodeValidity(validStatusCode: [Int]) throws {
        if !validStatusCode.contains(statusCode) {
            throw ApiError.invalidStatusCode(statusCode)
        }
    }
}
