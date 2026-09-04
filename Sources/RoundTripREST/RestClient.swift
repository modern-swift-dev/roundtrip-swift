#if canImport(Combine)
    import Combine
    import Foundation

    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
    import RoundTrip

    /// Base REST client implementation with support for API keys, custom headers,
    /// and standardized error handling
    ///
    /// Example:
    /// ```swift
    /// let client = RestClient(
    ///     baseURLProvider: baseURL,
    ///     apiKeyProvider: apiKey,
    ///     service: NetworkService()
    /// )
    /// let response = try await client.execute(request: myRequest)
    /// ```
    /// The client stores only immutable `Sendable` collaborators. Foundation's JSON
    /// coders and Combine's subject support synchronized use from concurrent callers.
    public final class RestClient: RestClientProtocol, @unchecked Sendable {

        private let errorSubject: PassthroughSubject<ApiError, Never>

        /// The Network service for this Rest API
        public let networkService: any NetworkServiceProtocol

        /// Return the base url of the rest client
        public let baseURLProvider: any BaseURLProvider

        /// The Api Key
        public let apiKeyProvider: (any ApiKeyProvider)?

        /// The default http header provider
        public let headerProvider: (any DefaultHttpHeaderProvider)?

        /// The Default JSON Decoder for responses
        public let decoder: JSONDecoder

        /// The Default JSON Encoder for request body
        public let encoder: JSONEncoder

        /// Creates a REST client.
        /// - Parameters:
        ///   - baseURLProvider: The provider for the request base URL.
        ///   - apiKeyProvider: The provider for the API key.
        ///   - service: The network service that provides a URL session.
        ///   - headerProvider: The provider for headers added to each request.
        ///   - errorSubject: The subject that receives API errors.
        ///   - decoder: The JSON decoder for responses.
        ///   - encoder: The JSON encoder for request bodies.
        public init(
            baseURLProvider: any BaseURLProvider,
            apiKeyProvider: any ApiKeyProvider,
            service: any NetworkServiceProtocol,
            headerProvider: (any DefaultHttpHeaderProvider)?,
            errorSubject: PassthroughSubject<ApiError, Never>,
            decoder: JSONDecoder = RoundTripRESTSupport.makeJSONDecoder(),
            encoder: JSONEncoder = RoundTripRESTSupport.makeJSONEncoder()
        ) {
            self.baseURLProvider = baseURLProvider
            self.apiKeyProvider = apiKeyProvider
            self.headerProvider = headerProvider
            self.encoder = encoder
            self.decoder = decoder
            networkService = service
            self.errorSubject = errorSubject
        }

        /// Returns the current API key from the configured provider, if available.
        public func apiKey() async -> String? {
            await apiKeyProvider?.apiKey
        }

        /// Returns the current API key, or throws when none is available.
        public func requireApiKey() async throws -> String {
            guard let apiKey = await apiKey(), !apiKey.isEmpty else {
                throw ApiError.authenticationRequired
            }
            return apiKey
        }

        /// Create a web-socket
        @MainActor public func webSocketClient(
            request: any URLRequestConvertible,
            keepAlive: WSSClient.KeepAliveConfig?
        ) throws -> WSSClient {
            let urlRequest = try request.buildRequest(baseUrl: nil, encoder: encoder)
            let task = networkService.session.webSocketTask(with: urlRequest)
            return WSSClient(
                task: task,
                keepAlive: keepAlive ?? .init(enabled: true, delay: 30.0)
            )
        }

        // MARK: - Request Conversion
        /// Create an URL request based on the specified URLRequestConvertible
        public func createRequest(_ convertible: any URLRequestConvertible) throws -> URLRequest {
            guard let baseURL = baseURLProvider.baseURL else {
                throw ApiError.invalidURL
            }

            var request = try convertible.buildRequest(baseUrl: baseURL, encoder: encoder)
            for (name, value) in headerProvider?.provideDefaultHeaders() ?? [:] {
                request.addHeader(value, name: name)
            }
            return request
        }

        /// Execute a request
        public func execute<ResponseType: Decodable>(
            request: some URLRequestConvertible,
            validStatusCode: [Int] = [200]
        ) async throws -> ApiOperationResult<ResponseType> {
            let response = try await execute(
                request: request,
                validStatusCode: validStatusCode
            )

            guard let data = response.data else {
                throw ApiError.emptyResponseBody
            }

            do {
                let json = try decoder.decode(ResponseType.self, from: data)
                return ApiOperationResult(response: response, value: json)
            } catch {
                throw ApiError.responseDecodingFailed(data, error)
            }
        }

        /// Execute a request
        public func execute(
            request: some URLRequestConvertible,
            validStatusCode: [Int] = [200]
        ) async throws -> ApiResponse {
            do {
                let request = try createRequest(request)
                let response = try await networkService.execute(request: request)
                try validateResponse(response: response, validStatusCode: validStatusCode)
                return response
            } catch {
                if let error = error as? ApiError {
                    errorSubject.send(error)
                }
                throw error
            }
        }

        /// Validate Response
        private func validateResponse(response: ApiResponse, validStatusCode: [Int]) throws {
            try response.checkForStatusCodeValidity(validStatusCode: validStatusCode)
        }

        /// Upload a file
        public func upload<ResponseType: Decodable>(
            request: some URLRequestConvertible,
            fileUrl: URL,
            progress: Progress? = nil,
            validStatusCode: [Int] = [200, 201]
        ) async throws -> ApiOperationResult<ResponseType> {
            do {
                let request = try createRequest(request)
                let response = try await networkService.upload(request: request, fileUrl: fileUrl, timeout: 3600, progress: progress)

                try validateResponse(response: response, validStatusCode: validStatusCode)

                guard let data = response.data else {
                    throw ApiError.emptyResponseBody
                }

                do {
                    let json = try decoder.decode(ResponseType.self, from: data)
                    return ApiOperationResult(response: response, value: json)
                } catch {
                    throw ApiError.responseDecodingFailed(data, error)
                }
            } catch {
                if let error = error as? ApiError {
                    errorSubject.send(error)
                }
                throw error
            }
        }

        /// Post a multipart request
        public func postMultipart<ResponseType: Decodable>(
            request: some URLRequestConvertible & MultipartBodyConvertible,
            progress: Progress? = nil,
            validStatusCode: [Int] = [200, 201]
        ) async throws -> ApiOperationResult<ResponseType> {
            let response = try await postMultipart(
                request: request,
                progress: progress,
                validStatusCode: validStatusCode
            )

            guard let data = response.data else {
                throw ApiError.emptyResponseBody
            }

            do {
                let json = try decoder.decode(ResponseType.self, from: data)
                return ApiOperationResult(response: response, value: json)
            } catch {
                if let error = error as? ApiError {
                    throw error
                }
                throw ApiError.responseDecodingFailed(data, error)
            }
        }

        /// Post a multipart request
        public func postMultipart(
            request: some URLRequestConvertible & MultipartBodyConvertible,
            progress: Progress? = nil,
            validStatusCode: [Int] = [200, 201]
        ) async throws -> ApiResponse {
            do {
                let body = try request.multiPartBody(encoder: encoder)
                defer {
                    body.cleanup()
                }
                var request = try createRequest(request)
                request = try request.postMultipart(authorizations: nil, body: body)

                let response = try await networkService.multiPartUpload(request: request, body: body, timeout: 3600, progress: progress)

                try validateResponse(response: response, validStatusCode: validStatusCode)

                return response
            } catch {
                if let error = error as? ApiError {
                    errorSubject.send(error)
                }
                throw error
            }
        }

    }

    @usableFromInline enum RoundTripRESTSupport {
        @usableFromInline static func makeJSONEncoder() -> JSONEncoder {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            encoder.dateEncodingStrategy = .iso8601
            encoder.dataEncodingStrategy = .base64
            encoder.keyEncodingStrategy = .useDefaultKeys
            return encoder
        }

        @usableFromInline static func makeJSONDecoder() -> JSONDecoder {
            let decoder = JSONDecoder()
            decoder.nonConformingFloatDecodingStrategy = .throw
            decoder.dateDecodingStrategy = .iso8601
            decoder.dataDecodingStrategy = .base64
            decoder.keyDecodingStrategy = .useDefaultKeys
            return decoder
        }
    }

#endif
