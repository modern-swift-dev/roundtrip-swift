import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public extension URLRequestBuilder {

    /// Http headers. See https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers
    enum HttpHeader {

        /// `Authorization`
        case authorization(String)

        /// `Accept-Encoding`
        case acceptEncoding(String)

        /// `Accept-Charset`
        case acceptCharset(String)

        /// `Accept-Language`
        case acceptLanguage(Locale)

        /// `Accept-Language`
        case acceptLanguageRaw(String)

        /// `Accept`
        case accept(URLRequestBuilder.MimeType)

        /// `Accept`
        case acceptRaw(String)

        /// `Content-Type`
        case contentType(URLRequestBuilder.MimeType)

        /// `Content-Type`
        case contentTypeRaw(String)

        /// `Content-Length`
        case contentLength(UInt64)

        /// `If-Modified-Since`
        case ifModifiedSince(Date)

        /// `If-Unmodified-Since`
        case ifUnmodifiedSince(Date)

        /// `If-Match`
        case ifMatch(String)

        /// `If-None-Match`
        case ifNoneMatch(String)

        /// `DNT`
        case doNotTrack(Bool)

        /// Return the header name for inclusion
        func getKey() -> String {
            switch self {
                case .doNotTrack:
                    "DNT"
                case .authorization:
                    "Authorization"
                case .acceptCharset:
                    "Accept-Charset"
                case .acceptLanguage:
                    "Accept-Language"
                case .acceptLanguageRaw:
                    "Accept-Language"
                case .acceptEncoding:
                    "Accept-Encoding"
                case .accept:
                    "Accept"
                case .contentLength:
                    "Content-Length"
                case .acceptRaw:
                    "Accept"
                case .ifModifiedSince:
                    "If-Modified-Since"
                case .ifUnmodifiedSince:
                    "If-Unmodified-Since"
                case .ifMatch:
                    "If-Match"
                case .ifNoneMatch:
                    "If-None-Match"
                case .contentType:
                    "Content-Type"
                case .contentTypeRaw:
                    "Content-Type"
            }
        }

        /// Return the value
        func getValue() -> String {
            switch self {
                case let .doNotTrack(value):
                    return value ? "1" : "0"
                case let .authorization(value):
                    return value
                case let .acceptCharset(value):
                    return value
                case let .acceptLanguageRaw(value):
                    return value
                case let .acceptLanguage(value):
                    guard let lang = value.language.languageCode?.identifier else {
                        return "en"
                    }

                    guard let region = value.language.region?.identifier else {
                        return lang
                    }

                    return "\(lang)-\(region)"
                case let .acceptEncoding(value):
                    return value
                case let .accept(type):
                    return type.rawValue
                case let .acceptRaw(value):
                    return value
                case let .contentType(type):
                    return type.rawValue
                case let .contentLength(size):
                    return "\(size)"
                case let .contentTypeRaw(value):
                    return value
                case let .ifModifiedSince(date):
                    return DateFormatter.httpHeaderFormatter.string(from: date)
                case let .ifUnmodifiedSince(date):
                    return DateFormatter.httpHeaderFormatter.string(from: date)
                case let .ifMatch(value):
                    return value
                case let .ifNoneMatch(value):
                    return value
            }
        }

        var debugDescription: String {
            "\(getKey())=\(getValue())"
        }
    }

    /// Add a http header
    /// - parameter header: The header to add
    /// - parameter value: The value of the header
    /// - returns: `self`
    func addHeader(_ header: String, value: String) -> Self {
        headers[header] = value
        return self
    }

    /// Add a http header
    /// - parameter header: The header to add
    /// - returns: `self`
    func addHeader(_ header: HttpHeader) -> Self {
        headers[header.getKey()] = header.getValue()
        return self
    }

}
