#if canImport(Combine)
    import Combine
    import Dispatch
    import Foundation
    import os

    #if canImport(Security)
        import Security
    #endif

    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
    import RoundTrip

    /// Network service implementation handling HTTP requests and responses
    /// Supports background operations and provides detailed metrics
    /// `URLSession`, `OperationQueue`, and the delegate's Combine subject are safe to
    /// use from concurrent callers. All stored references are fixed during initialization.
    public final class NetworkService: NSObject, NetworkServiceProtocol, @unchecked Sendable {
        private static let refreshCoordinator = AccessTokenRefreshCoordinator()

        /// The URL Session to be used
        public let session: URLSession

        /// Retained for the session lifetime so its header publisher remains available.
        private let headerObserver: NetworkServiceDelegate

        /// The Operation Queue
        private let queue: OperationQueue

        private let accessTokenRefresher: (any AccessTokenRefresher)?

        private static func makeQueue() -> OperationQueue {
            let queue = OperationQueue()
            let rootName = Bundle.main.bundleIdentifier ?? "NetworkService"
            queue.name = "\(rootName).NetworkService"
            queue.qualityOfService = .default
            queue.underlyingQueue = DispatchQueue.global(qos: .default)
            return queue
        }

        /// Publishers of http headers received by this session. Allowing
        /// to process global headers that can be sent by the back-end by any request
        /// such as `api-key-expires-at`
        public var httpHeaders: AnyPublisher<[AnyHashable: Any], Never> {
            headerObserver.httpHeaders.eraseToAnyPublisher()
        }

        /// Initializer
        /// - parameter configuration: The URL Configuration, defaults to `.default`
        public init(
            configuration: URLSessionConfiguration = .default,
            serverTrustPolicy: ServerTrustPolicy = .systemDefault,
            accessTokenRefresher: (any AccessTokenRefresher)? = nil
        ) {
            let queue = Self.makeQueue()
            let headerObserver = NetworkServiceDelegate(serverTrustPolicy: serverTrustPolicy)
            self.queue = queue
            self.headerObserver = headerObserver
            self.accessTokenRefresher = accessTokenRefresher
            session = URLSession(configuration: configuration, delegate: headerObserver, delegateQueue: queue)
            super.init()
        }

        /// Deinit
        deinit {
            session.invalidateAndCancel()
            queue.cancelAllOperations()
        }

        /// Create a ApiResponse/ApiError for specified URL Request
        /// - parameter request: The URL Request
        /// - returns: The repsonse
        public func execute(request: URLRequest) async throws -> ApiResponse {
            try await executeWithRefresh(request: request) { [self] request in
                try await executeWithoutRefresh(request: request)
            }
        }

        private func executeWithoutRefresh(request: URLRequest) async throws -> ApiResponse {
            do {
                let (data, response) = try await session.data(for: request)
                return ApiResponse(data: data, response: response)
            } catch {
                throw error.asApiError
            }
        }

        /// Create a ApiResponse/ApiError Upload for specified URL Request
        /// - parameter request: The URL Request
        /// - parameter fileUrl: The File URL to upload
        /// - parameter timeout: The timeout delay for the upload
        /// - parameter progress: The progress indicator
        /// - returns: The actual response
        public func upload(
            request: URLRequest,
            fileUrl: URL,
            timeout: TimeInterval = 3600.0,
            progress: Progress?
        ) async throws -> ApiResponse {
            try await executeWithRefresh(request: request) { [self] request in
                try await uploadWithoutRefresh(
                    request: request,
                    fileUrl: fileUrl,
                    timeout: timeout,
                    progress: progress
                )
            }
        }

        private func uploadWithoutRefresh(
            request: URLRequest,
            fileUrl: URL,
            timeout: TimeInterval,
            progress: Progress?
        ) async throws -> ApiResponse {
            let taskReference = URLSessionTaskReference()
            var uploadRequest = request
            uploadRequest.timeoutInterval = timeout

            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in

                    let task = session.uploadTask(with: uploadRequest, fromFile: fileUrl) { data, response, error in
                        if let error {
                            continuation.resume(throwing: error)
                            return
                        }

                        continuation.resume(returning: ApiResponse(data: data, response: response))
                    }

                    taskReference.store(task)
                    if let progress, let size = fileSize(at: fileUrl) {
                        progress.totalUnitCount += size
                        progress.addChild(task.progress, withPendingUnitCount: size)
                    }
                    task.resume()

                }
            } onCancel: {
                taskReference.cancel()
            }
        }

        /// Create a ApiResponse/ApiError Upload for specified URL Request and body
        /// - parameter request: The URL Request
        /// - parameter body: The Multipart Body to upload
        /// - parameter timeout: The timeout delay
        /// - parameter progress: The progress indicator
        /// - returns: The actual Response
        public func multiPartUpload(
            request: URLRequest,
            body: MultipartBody,
            timeout: TimeInterval = 3600.0,
            progress: Progress?
        ) async throws -> ApiResponse {
            defer {
                body.cleanup()
            }
            let fileURL = body.url
            return try await executeWithRefresh(request: request) { [self] request in
                try await uploadWithoutRefresh(
                    request: request,
                    fileUrl: fileURL,
                    timeout: timeout,
                    progress: progress
                )
            }
        }

        /// Download a file to the filesystem
        /// - parameter url: The url to download
        /// - parameter directory: The directory to save the file to.
        /// - parameter progress: The progress for the download
        /// - returns: The Local File URL for the resulting downloads
        /// - throws: ApiError for all network-related errors that may occurs
        public func download(url: URL, in directory: URL, progress: Progress?) async throws -> URL {
            let taskReference = URLSessionTaskReference()
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    let task = session.downloadTask(with: URLRequest(url: url), completionHandler: { tempUrl, response, error in

                        if let response = response as? HTTPURLResponse, response.statusCode != 200 {
                            continuation.resume(
                                throwing: ApiError.invalidStatusCode(
                                    response.statusCode,
                                    ApiResponse(data: nil, response: response)
                                )
                            )
                            return
                        }

                        if let error {
                            continuation.resume(throwing: error.asApiError)
                            return
                        }

                        if let tempUrl {
                            do {
                                let localUrl = directory
                                    .appendingPathComponent(UUID().uuidString)
                                    .appendingPathExtension(url.pathExtension)

                                try FileManager.default.moveItem(at: tempUrl, to: localUrl)
                                continuation.resume(returning: localUrl)
                                return
                            } catch {
                                continuation.resume(throwing: ApiError.responseDecodingFailed(nil, error))
                                return
                            }
                        }

                        continuation.resume(throwing: ApiError.unknown(nil))
                    })
                    taskReference.store(task)
                    progress?.addChild(task.progress, withPendingUnitCount: 1)
                    task.resume()
                }
            } onCancel: {
                taskReference.cancel()
            }
        }

        /// Cancel all
        public func cancelAll() {
            session.getAllTasks { tasks in
                for task in tasks {
                    task.cancel()
                }
            }
        }

        /// invalidate
        public func invalidate() {
            session.invalidateAndCancel()
        }

        private func executeWithRefresh(
            request: URLRequest,
            operation: @Sendable (URLRequest) async throws -> ApiResponse
        ) async throws -> ApiResponse {
            let response = try await operation(request)
            guard response.isUnauthorized,
                  let failedAccessToken = bearerToken(from: request),
                  let accessToken = try await refreshAccessToken(after: failedAccessToken) else {
                return response
            }

            return try await operation(replacingBearerToken(in: request, with: accessToken))
        }

        private func refreshAccessToken(after failedAccessToken: String) async throws -> String? {
            guard let accessTokenRefresher else {
                return nil
            }
            return try await Self.refreshCoordinator.refresh(
                failedAccessToken: failedAccessToken,
                refresher: accessTokenRefresher,
                execute: { [self] request in
                    try await executeWithoutRefresh(request: request)
                }
            )
        }

        private func bearerToken(from request: URLRequest) -> String? {
            guard let authorization = request.value(forHTTPHeaderField: "Authorization"),
                  authorization.hasPrefix("Bearer ") else {
                return nil
            }
            return String(authorization.dropFirst("Bearer ".count))
        }

        private func replacingBearerToken(in request: URLRequest, with accessToken: String) -> URLRequest {
            var request = request
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            return request
        }

        private func fileSize(at url: URL) -> Int64? {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let size = attributes[.size] as? NSNumber {
                    return size.int64Value
                }
                return attributes[.size] as? Int64
            } catch {
                Logger(subsystem: "RoundTripREST", category: "NetworkService")
                    .error("Unable to read upload size: \(String(describing: error), privacy: .public)")
                return nil
            }
        }
    }

    private extension ApiResponse {
        var isUnauthorized: Bool {
            statusCode == 401
        }
    }

    private actor AccessTokenRefreshCoordinator {
        private typealias RefreshResult = Result<String?, any Error>

        private struct Key: Hashable, Sendable {
            let refresher: ObjectIdentifier
            let failedAccessToken: String
        }

        private struct GenerationKey: Hashable, Sendable {
            let key: Key
            let generation: Int
        }

        private var activeGenerations: [Key: Int] = [:]
        private var nextGeneration = 0
        private var completions: [GenerationKey: RefreshResult] = [:]
        private var waiterCounts: [GenerationKey: Int] = [:]

        func refresh(
            failedAccessToken: String,
            refresher: any AccessTokenRefresher,
            execute: @escaping NetworkRequestExecutor
        ) async throws -> String? {
            let key = Key(
                refresher: ObjectIdentifier(refresher),
                failedAccessToken: failedAccessToken
            )
            if let generation = activeGenerations[key] {
                return try await waitForRefresh(
                    generationKey: GenerationKey(key: key, generation: generation)
                )
            }

            nextGeneration += 1
            let generationKey = GenerationKey(key: key, generation: nextGeneration)
            activeGenerations[key] = generationKey.generation
            do {
                let accessToken = try await refresher.refreshAccessToken(
                    after: failedAccessToken,
                    execute: execute
                )
                finish(generationKey: generationKey, result: .success(accessToken))
                return accessToken
            } catch {
                finish(generationKey: generationKey, result: .failure(error))
                throw error
            }
        }

        private func waitForRefresh(generationKey: GenerationKey) async throws -> String? {
            waiterCounts[generationKey, default: 0] += 1
            defer {
                waiterCounts[generationKey, default: 0] -= 1
                if waiterCounts[generationKey] == 0 {
                    waiterCounts[generationKey] = nil
                    completions[generationKey] = nil
                }
            }
            while completions[generationKey] == nil {
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(25))
            }
            guard let completion = completions[generationKey] else {
                preconditionFailure("Refresh completion disappeared while a waiter was active")
            }
            return try completion.get()
        }

        private func finish(generationKey: GenerationKey, result: RefreshResult) {
            if waiterCounts[generationKey, default: 0] > 0 {
                completions[generationKey] = result
            }
            activeGenerations[generationKey.key] = nil
        }
    }

    /// Access to the task reference is protected by the lock. Cancellation can race
    /// with URLSession task creation without exposing the mutable reference.
    private final class URLSessionTaskReference: @unchecked Sendable {
        private let lock = NSLock()
        private var task: URLSessionTask?
        private var isCancelled = false

        func store(_ task: URLSessionTask) {
            lock.lock()
            self.task = task
            let shouldCancel = isCancelled
            lock.unlock()

            if shouldCancel {
                task.cancel()
            }
        }

        func cancel() {
            lock.lock()
            isCancelled = true
            let task = task
            lock.unlock()
            task?.cancel()
        }
    }

    /// Combine subjects serialize downstream delivery, so delegate callbacks may publish
    /// headers from the URL session's operation queue.
    @objc public final class NetworkServiceDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        private let serverTrustPolicy: ServerTrustPolicy

        /// Response headers collected as URL session tasks finish.
        public let httpHeaders: PassthroughSubject<[AnyHashable: Any], Never> = .init()

        /// Creates a delegate using the requested server-trust behavior.
        public init(serverTrustPolicy: ServerTrustPolicy = .systemDefault) {
            self.serverTrustPolicy = serverTrustPolicy
        }

        /// Log performance information for the application HTTP Request
        public func urlSession(_: URLSession, task: URLSessionTask, didFinishCollecting _: URLSessionTaskMetrics) {
            if let response = task.response as? HTTPURLResponse {
                if !response.allHeaderFields.isEmpty {
                    httpHeaders.send(response.allHeaderFields)
                }
            }
        }

        /// Handles server-trust challenges according to ``ServerTrustPolicy``.
        public func urlSession(
            _: URLSession,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            guard serverTrustPolicy == .trustAllCertificates,
                  challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
                  let serverTrust = challenge.protectionSpace.serverTrust else {
                completionHandler(.performDefaultHandling, nil)
                return
            }

            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        }
    }

#endif
