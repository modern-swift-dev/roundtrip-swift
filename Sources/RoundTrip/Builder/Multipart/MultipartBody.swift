import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Represents a multipart/form-data request body with support for various content types
/// including files, JSON data, and form fields.
///
/// Example:
/// ```swift
/// let builder = try MultipartBody.Builder()
/// try builder.addPart(name: "file", file: fileURL)
/// try builder.addJsonPart(name: "metadata", data: metadata)
/// let body = try builder.build()
/// ```
public struct MultipartBody {

    /// The content type
    public let contentType: String

    /// The URL of the body
    public let url: URL

    /// The size of the body
    public let size: UInt64?

    /// Cleanup the file
    public func cleanup() {

        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                RoundTripSupport.log(error)
            }
        }
    }

    /// Add missing request headers
    public func apply(_ request: URLRequest) -> URLRequest {
        var request = request
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if let size {
            request.setValue("\(size)", forHTTPHeaderField: "Content-Length")
        }
        return request
    }

    /// Add missing request headers
    public func apply(_ builder: URLRequestBuilder) {
        _ = builder.addHeader(.contentTypeRaw(contentType))
        if let size {
            _ = builder.addHeader(.contentLength(size))
        }
    }
}
