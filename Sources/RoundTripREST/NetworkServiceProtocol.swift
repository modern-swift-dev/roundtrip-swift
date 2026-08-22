#if canImport(Combine)
    import Combine
    import Foundation

    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
    import RoundTrip

    /// Protocol defining network operations for HTTP requests.
    /// Provides a lower-level interface for executing network operations compared to RestClientProtocol.
    public protocol NetworkServiceProtocol: Sendable {

        /// Publisher for received HTTP headers from responses.
        /// Useful for processing global headers sent by the backend.
        var httpHeaders: AnyPublisher<[AnyHashable: Any], Never> { get }

        /// The underlying URLSession used for network requests
        var session: URLSession { get }

        /// Executes a basic HTTP request
        /// - Parameter request: The URLRequest to execute
        /// - Returns: API response containing status code, headers and data
        /// - Throws: ApiError if request fails
        func execute(request: URLRequest) async throws -> ApiResponse

        /// Uploads a file using a HTTP request
        /// - Parameters:
        ///   - request: The URLRequest containing upload details
        ///   - fileUrl: Local URL of file to upload
        ///   - timeout: Maximum time to wait for upload completion
        ///   - progress: Optional progress tracking
        /// - Returns: API response from the server
        /// - Throws: ApiError if upload fails
        func upload(
            request: URLRequest,
            fileUrl: URL,
            timeout: TimeInterval,
            progress: Progress?
        ) async throws -> ApiResponse

        /// Executes a multipart form upload request
        /// - Parameters:
        ///   - request: The URLRequest containing upload details
        ///   - body: Multipart form data to upload
        ///   - timeout: Maximum time to wait for upload completion
        ///   - progress: Optional progress tracking
        /// - Returns: API response from the server
        /// - Throws: ApiError if upload fails
        func multiPartUpload(
            request: URLRequest,
            body: MultipartBody,
            timeout: TimeInterval,
            progress: Progress?
        ) async throws -> ApiResponse

        /// Downloads a file from a URL
        /// - Parameters:
        ///   - url: Remote URL to download from
        ///   - directory: Local directory to save downloaded file
        ///   - progress: Optional progress tracking
        /// - Returns: Local URL where file was saved
        /// - Throws: ApiError if download fails
        func download(url: URL, in directory: URL, progress: Progress?) async throws -> URL

        /// Cancels all ongoing network operations
        func cancelAll()

        /// Invalidates the session and cancels ongoing operations
        func invalidate()
    }

#endif
