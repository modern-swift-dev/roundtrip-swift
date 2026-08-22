#if canImport(Combine)
    import Combine
    import Foundation

    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
    import RoundTrip

    /// Protocol defining a REST client capable of executing HTTP requests and handling responses.
    /// Supports standard REST operations, file uploads, and paginated results.
    ///
    /// RestClientProtocol provides a high-level interface for making HTTP requests with built-in support for:
    /// - JSON encoding/decoding
    /// - File uploads
    /// - Multipart form data
    /// - Pagination
    /// - Authentication
    ///
    /// Example:
    /// ```swift
    /// let client = RestClient(baseURLProvider: baseURL,
    ///                        apiKeyProvider: apiKey,
    ///                        service: NetworkService())
    ///
    /// let response = try await client.execute(request: myRequest)
    /// ```
    public protocol RestClientProtocol: Sendable {
        /// Network service handling the underlying HTTP operations
        var networkService: any NetworkServiceProtocol { get }

        /// Return the base url of the rest client
        var baseURLProvider: any BaseURLProvider { get }

        /// The Api Key
        var apiKeyProvider: (any ApiKeyProvider)? { get }

        /// Returns the current API key from the configured provider, if available.
        func apiKey() async -> String?

        /// Returns the current API key, or throws when none is available.
        func requireApiKey() async throws -> String

        /// The default http header provider
        var headerProvider: (any DefaultHttpHeaderProvider)? { get }

        /// The Default JSON Decoder for responses
        var decoder: JSONDecoder { get }

        /// The Default JSON Encoder for request body
        var encoder: JSONEncoder { get }

        /// Create a web-socket
        @MainActor func webSocketClient(
            request: any URLRequestConvertible,
            keepAlive: WSSClient.KeepAliveConfig?
        ) throws -> WSSClient

        /// Creates a URLRequest from a URLRequestConvertible type
        /// - Parameter convertible: The request specification
        /// - Returns: A configured URLRequest with base URL and headers applied
        /// - Throws: ApiError if request creation fails
        func createRequest(_ convertible: any URLRequestConvertible) throws -> URLRequest

        /// Executes a request and decodes the response to the specified type
        /// - Parameters:
        ///   - request: The request to execute
        ///   - validStatusCode: HTTP status codes considered valid for this request
        /// - Returns: Operation result containing the decoded response and metadata
        /// - Throws: ApiError if request fails or response cannot be decoded
        func execute<ResponseType: Decodable>(
            request: some URLRequestConvertible,
            validStatusCode: [Int]
        ) async throws -> ApiOperationResult<ResponseType>

        /// Executes a request without decoding the response
        /// - Parameters:
        ///   - request: The request to execute
        ///   - validStatusCode: HTTP status codes considered valid for this request
        /// - Returns: Raw API response with status code and data
        /// - Throws: ApiError if request fails
        func execute(
            request: some URLRequestConvertible,
            validStatusCode: [Int]
        ) async throws -> ApiResponse

        /// Uploads a file and decodes the response
        /// - Parameters:
        ///   - request: The request containing upload details
        ///   - fileUrl: Local URL of file to upload
        ///   - progress: Optional progress tracking
        ///   - validStatusCode: HTTP status codes considered valid for this request
        /// - Returns: Operation result containing the decoded response and metadata
        /// - Throws: ApiError if upload fails or response cannot be decoded
        func upload<ResponseType: Decodable>(
            request: some URLRequestConvertible,
            fileUrl: URL,
            progress: Progress?,
            validStatusCode: [Int]
        ) async throws -> ApiOperationResult<ResponseType>

        /// Executes a multipart form request and decodes the response
        /// - Parameters:
        ///   - request: The multipart request specification
        ///   - progress: Optional progress tracking
        ///   - validStatusCode: HTTP status codes considered valid for this request
        /// - Returns: Operation result containing the decoded response and metadata
        /// - Throws: ApiError if request fails or response cannot be decoded
        func postMultipart<ResponseType: Decodable>(
            request: some URLRequestConvertible & MultipartBodyConvertible,
            progress: Progress?,
            validStatusCode: [Int]
        ) async throws -> ApiOperationResult<ResponseType>

        /// Executes a multipart form request without decoding the response
        /// - Parameters:
        ///   - request: The multipart request specification
        ///   - progress: Optional progress tracking
        ///   - validStatusCode: HTTP status codes considered valid for this request
        /// - Returns: Raw API response with status code and data
        /// - Throws: ApiError if request fails
        func postMultipart(
            request: some URLRequestConvertible & MultipartBodyConvertible,
            progress: Progress?,
            validStatusCode: [Int]
        ) async throws -> ApiResponse
    }

#endif
