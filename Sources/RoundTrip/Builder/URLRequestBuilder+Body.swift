import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - Body
public extension URLRequestBuilder {

    /// Set a Binary Body
    /// - parameter body: the data of the body
    /// - returns: `self`
    func setBody(_ body: Data) -> Self {
        self.body = body
        _ = addHeader(.contentLength(UInt64(body.count)))
        return self
    }

    /// Set a JSON Body
    /// - parameter body: The `Encodable` body
    /// - parameter encoder: The JSONEncoder
    /// - returns: `self`
    /// - throws: An error if the encoder cannot encode the body.
    func setBody(
        _ body: any Encodable,
        encoder: JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            encoder.dateEncodingStrategy = .iso8601
            encoder.dataEncodingStrategy = .base64
            return encoder
        }()
    ) throws -> Self {
        let data = try encoder.encode(body)
        self.body = data
        _ = addHeader(.contentType(.json))
        _ = addHeader(.contentLength(UInt64(data.count)))
        return self
    }

    /// Set a multi part body
    /// - parameter body: The `Multipart` body
    /// - parameter includeBinaryBody: Whether to load the multipart file into the request body
    /// - returns: `self`
    /// - throws: An error if the multipart file cannot be read.
    func setBody(_ body: MultipartBody, includeBinaryBody: Bool = false) throws -> Self {
        body.apply(self)

        if includeBinaryBody {
            let data = try Data(contentsOf: body.url, options: .mappedIfSafe)
            self.body = data
        }
        return self
    }
}
