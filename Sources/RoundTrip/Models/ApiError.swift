import Foundation

#if canImport(Combine)
    import Combine
#endif

/// Comprehensive error type for HTTP operations covering network, encoding/decoding,
/// and various HTTP-specific error cases.
///
/// Example:
/// ```swift
/// catch let error as ApiError {
///     switch error {
///     case .networkUnreachable:
///         // Handle network error
///     case .invalidStatusCode(let code):
///         // Handle HTTP error
///     }
/// }
/// ```
public enum ApiError: Error {

    /// An unknown error from the network stack.
    case unknown((any Error)?)

    /// A `URLError` encountered, which prevented connecting to the server
    case networkUnreachable

    /// The base url is invalid
    case invalidURL

    /// Response does not have a satisfactory status code
    case invalidStatusCode(Int, ApiResponse? = nil)

    /// Request Encoding Failed, before sending it over the network
    case requestEncodingFailed

    /// Response Decoding Failed, after receiving response from the network
    case responseDecodingFailed(Data?, any Error)

    /// A case where the response body was unexpectedly empty
    case emptyResponseBody

    /// File size too big
    case fileSizeTooBig(Int64)

    /// File type is not supported
    case unsupportedFileType

    /// File not found at specified path
    case fileNotFound(URL)

    /// Insecure Connection Detected
    case insecureConnection

    /// Authentication credentials are required but unavailable.
    case authenticationRequired

    /// A file system error occured when saving data on disk
    case fileSystemError

    /// The request was cancelled
    case cancelled
}

public extension Error {

    var asApiError: ApiError {
        if let error = self as? ApiError {
            return error
        }

        if let error = self as? URLError {
            switch error.code {
                case .notConnectedToInternet,
                     .cannotFindHost,
                     .cannotConnectToHost,
                     .timedOut,
                     .networkConnectionLost,
                     .dataNotAllowed,
                     .dnsLookupFailed,
                     .cannotLoadFromNetwork,
                     .callIsActive,
                     .internationalRoamingOff,
                     .httpTooManyRedirects,
                     .resourceUnavailable,
                     .redirectToNonExistentLocation:
                    return .networkUnreachable

                case .cannotCloseFile,
                     .cannotCreateFile,
                     .cannotMoveFile,
                     .cannotOpenFile,
                     .cannotWriteToFile,
                     .noPermissionsToReadFile:
                    return .fileSystemError

                case .unsupportedURL,
                     .badURL,
                     .fileDoesNotExist,
                     .fileIsDirectory:
                    return .requestEncodingFailed

                case .badServerResponse,
                     .dataLengthExceedsMaximum,
                     .cannotDecodeContentData,
                     .cannotDecodeRawData,
                     .cannotParseResponse,
                     .downloadDecodingFailedMidStream,
                     .downloadDecodingFailedToComplete,
                     .zeroByteResource:
                    return .responseDecodingFailed(nil, error)

                case .userAuthenticationRequired,
                     .userCancelledAuthentication,
                     .secureConnectionFailed,
                     .serverCertificateHasBadDate,
                     .serverCertificateUntrusted,
                     .serverCertificateHasUnknownRoot,
                     .serverCertificateNotYetValid,
                     .appTransportSecurityRequiresSecureConnection:
                    return .insecureConnection

                case .cancelled:
                    return .cancelled

                default:
                    return .unknown(error)
            }
        }
        return .unknown(self)
    }

}

// MARK: Combine
#if canImport(Combine)
    public extension ApiError {

        /// Sugar-syntax to easily create a Combine `Fail` from an API Error
        func fail<T>() -> AnyPublisher<T, Self> {
            Fail(error: self).eraseToAnyPublisher()
        }
    }
#endif

public extension ApiError {
    /// Whether the error should be reported to an error-capture service.
    var isCapturable: Bool {
        switch self {
            case let .unknown(error):
                error.map(RoundTripSupport.isCapturable) ?? false
            case .networkUnreachable:
                false
            case .invalidURL:
                true
            case .invalidStatusCode:
                true
            case .requestEncodingFailed:
                true
            case .responseDecodingFailed:
                true
            case .emptyResponseBody:
                true
            case .insecureConnection:
                false
            case .authenticationRequired:
                false
            case .fileSystemError:
                true
            case .cancelled:
                false
            case .fileSizeTooBig:
                true
            case .unsupportedFileType:
                true
            case .fileNotFound:
                true
        }
    }
}
