#if canImport(Combine)
    import Combine
    import Dispatch
    import Foundation
    import os

    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
    import RoundTrip

    /// Network service implementation handling HTTP requests and responses
    /// Supports background operations and provides detailed metrics
    /// `URLSession`, `OperationQueue`, and the delegate's Combine subject are safe to
    /// use from concurrent callers. All stored references are fixed during initialization.
    public final class NetworkService: NSObject, NetworkServiceProtocol, @unchecked Sendable {

        /// The URL Session to be used
        public let session: URLSession

        /// Retained for the session lifetime so its header publisher remains available.
        private let headerObserver: NetworkServiceDelegate

        /// The Operation Queue
        private let queue: OperationQueue

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
        public init(configuration: URLSessionConfiguration = .default) {
            let queue = Self.makeQueue()
            let headerObserver = NetworkServiceDelegate()
            self.queue = queue
            self.headerObserver = headerObserver
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

            let taskReference = URLSessionTaskReference()
            var uploadRequest = request
            uploadRequest.timeoutInterval = timeout

            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    let task = session.uploadTask(with: uploadRequest, fromFile: body.url) { data, response, error in
                        if let error {
                            continuation.resume(throwing: error)
                            return
                        }

                        continuation.resume(returning: ApiResponse(data: data, response: response))
                    }

                    taskReference.store(task)
                    if let progress, let size = fileSize(at: body.url) {
                        progress.totalUnitCount += size
                        progress.addChild(task.progress, withPendingUnitCount: size)
                    }

                    task.resume()
                }
            } onCancel: {
                taskReference.cancel()
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
        /// Response headers collected as URL session tasks finish.
        public let httpHeaders: PassthroughSubject<[AnyHashable: Any], Never> = .init()

        /// Log performance information for the application HTTP Request
        public func urlSession(_: URLSession, task: URLSessionTask, didFinishCollecting _: URLSessionTaskMetrics) {
            if let response = task.response as? HTTPURLResponse {
                if !response.allHeaderFields.isEmpty {
                    httpHeaders.send(response.allHeaderFields)
                }
            }
        }
    }

#endif
