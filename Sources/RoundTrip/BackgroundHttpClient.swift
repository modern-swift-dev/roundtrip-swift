#if canImport(Combine)
    import Combine
    import Foundation
    import Synchronization

    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif

    /// HTTP client specifically designed for background upload/download operations that can continue
    /// when the app is in the background or terminated.
    ///
    /// Example:
    /// ```swift
    /// let client = BackgroundHttpClient(name: "background-transfers")
    /// let task = try client.download(urlRequest: request)
    /// ```
    ///
    /// Thread safety: the URL session is immutable after initialization, completion-handler access
    /// is protected by a mutex, and finished-task updates run on the main actor.
    public class BackgroundHttpClient: NSObject, @unchecked Sendable {

        public struct BackgroundTask: Sendable {
            public let sessionId: String
            public let requestURL: URL
            public let file: URL
        }

        private var sessionEvents: BackgroundSessionDelegate!

        /// The completion handler for background I/O.
        public var completionHandler: (@Sendable () -> Void)? {
            get {
                sessionEvents.completionHandlerState.withLock { $0 }
            }
            set {
                sessionEvents.completionHandlerState.withLock { $0 = newValue }
            }
        }

        /// The URL Session
        private(set) var session: URLSession!

        /// Background Session Events subject
        @MainActor @Published public var finishedTask: BackgroundTask?

        /// The dispatch queue for the cancellables
        private let httpClientQueue = DispatchQueue(label: "background-http-client-dispatch-queue", qos: .background)

        /// The operation queue
        private lazy var operationQueue: OperationQueue = {
            let queue = OperationQueue()
            queue.name = "background-http-client-operation-queue"
            queue.underlyingQueue = httpClientQueue
            return queue
        }()

        /// The Initializer
        /// - parameter name: The name of the session
        /// - parameter timeoutForRequest: See `URLSessionConfiguration.timeoutForRequest`
        /// - parameter timeoutForResource: See `URLSessionConfiguration.timeoutForResource`
        /// - parameter minimumTLSVersion: See `tls_protocol_version_t`
        /// - parameter maximumTLSVersion: See `tls_protocol_version_t`
        /// - parameter httpShouldUsePipelining: See `URLSessionConfiguration.httpShouldSetCookies`
        /// - parameter allowsCellularAccess: See `URLSessionConfiguration.allowsCellularAccess`
        /// - parameter httpShouldSetCookies: See `URLSessionConfiguration.httpShouldSetCookies`
        /// - parameter waitsForConnectivity: See `URLSessionConfiguration.waitsForConnectivity`
        /// - parameter sessionSendsLaunchEvents: See `URLSessionConfiguration.sessionSendsLaunchEvents`
        /// - parameter isDiscretionary: See `URLSessionConfiguration.isDiscretionary`
        /// - parameter requestCachePolicy: See `URLSessionConfiguration.requestCachePolicy`
        /// - parameter urlCache: See `URLSessionConfiguration.urlCache`
        @MainActor public init(
            name: String,
            timeoutForRequest: TimeInterval = 1800.0,
            timeoutForResource: TimeInterval = 1800.0,
            minimumTLSVersion: tls_protocol_version_t = .TLSv12,
            maximumTLSVersion: tls_protocol_version_t = .TLSv13,
            httpShouldUsePipelining: Bool = false,
            allowsCellularAccess: Bool = true,
            httpShouldSetCookies: Bool = true,
            waitsForConnectivity: Bool = true,
            sessionSendsLaunchEvents: Bool = true,
            isDiscretionary: Bool = true,
            requestCachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
            urlCache: URLCache = URLCache.shared
        ) {
            super.init()
            let configuration = URLSessionConfiguration.background(withIdentifier: name)
            configuration.tlsMinimumSupportedProtocolVersion = minimumTLSVersion
            configuration.tlsMaximumSupportedProtocolVersion = maximumTLSVersion
            configuration.timeoutIntervalForRequest = timeoutForRequest
            configuration.timeoutIntervalForResource = timeoutForResource
            configuration.httpShouldSetCookies = httpShouldSetCookies
            configuration.httpShouldUsePipelining = httpShouldUsePipelining
            configuration.requestCachePolicy = requestCachePolicy
            configuration.allowsCellularAccess = allowsCellularAccess
            configuration.sessionSendsLaunchEvents = sessionSendsLaunchEvents
            configuration.isDiscretionary = isDiscretionary
            configuration.urlCache = urlCache
            configuration.waitsForConnectivity = waitsForConnectivity
            createSession(configuration: configuration)
        }

        @MainActor init(configuration: URLSessionConfiguration) {
            super.init()
            createSession(configuration: configuration)
        }

        private func createSession(configuration: URLSessionConfiguration) {
            sessionEvents = BackgroundSessionDelegate { [weak self] task in
                Task { @MainActor [weak self] in
                    self?.finishedTask = task
                }
            }
            session = URLSession(
                configuration: configuration,
                delegate: sessionEvents,
                delegateQueue: operationQueue
            )
        }

        deinit {
            // URLSession keeps the delegate alive until existing transfers and callbacks finish.
            session.finishTasksAndInvalidate()
        }

        /// Download specified URL into a background session
        ///
        /// - parameter urlRequest: The URL request
        /// - parameter countOfBytesClientExpectsToSend: Byte size to send
        /// - parameter countOfBytesClientExpectsToReceive: Byte size to receive
        /// - returns: The URL Session Download Task
        /// - throws: An error if the request cannot be built.
        public func download(
            urlRequest: any URLRequestConvertible,
            countOfBytesClientExpectsToSend: Int64 = NSURLSessionTransferSizeUnknown,
            countOfBytesClientExpectsToReceive: Int64 = NSURLSessionTransferSizeUnknown
        ) throws -> URLSessionDownloadTask {

            let request = try urlRequest.buildRequest(baseUrl: nil, encoder: RoundTripSupport.makeJSONEncoder())
            let task = session.downloadTask(with: request)
            task.earliestBeginDate = Date.monotonic
            task.countOfBytesClientExpectsToSend = countOfBytesClientExpectsToSend
            task.countOfBytesClientExpectsToReceive = countOfBytesClientExpectsToReceive
            task.resume()
            return task
        }

        /// Upload specified URL into a background session
        ///
        /// - parameter request: The URL Request
        /// - parameter file: The File to upload
        /// - parameter countOfBytesClientExpectsToSend: Byte size to send when the file size is unavailable
        /// - parameter countOfBytesClientExpectsToReceive: Byte size expected in the response
        /// - returns: The URL Session Upload Task
        /// - throws: `ApiError.fileNotFound` for an invalid file, or an error if the request cannot be built.
        public func upload(
            request: any URLRequestConvertible,
            file: URL,
            countOfBytesClientExpectsToSend: Int64 = NSURLSessionTransferSizeUnknown,
            countOfBytesClientExpectsToReceive: Int64 = NSURLSessionTransferSizeUnknown
        ) throws -> URLSessionUploadTask {
            guard file.isFileURL, FileManager.default.fileExists(atPath: file.path) else {
                throw ApiError.fileNotFound(file)
            }

            let request = try request.buildRequest(baseUrl: nil, encoder: RoundTripSupport.makeJSONEncoder())
            let size = RoundTripSupport.fileSize(at: file)
            let task = session.uploadTask(with: request, fromFile: file)
            task.earliestBeginDate = Date.monotonic
            task.countOfBytesClientExpectsToSend = size ?? countOfBytesClientExpectsToSend
            task.countOfBytesClientExpectsToReceive = countOfBytesClientExpectsToReceive
            task.resume()
            return task
        }
    }

    // MARK: - URLSessionDownloadDelegate
    extension BackgroundHttpClient: URLSessionDownloadDelegate {

        public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            sessionEvents.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
        }

        public func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
            sessionEvents.urlSession(session, task: task, didFinishCollecting: metrics)
        }

        #if os(iOS) || os(watchOS)
            public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
                sessionEvents.urlSessionDidFinishEvents(forBackgroundURLSession: session)
            }
        #endif
    }

    /// Retained by URLSession through graceful invalidation, independently of the client.
    final class BackgroundSessionDelegate: NSObject, URLSessionDownloadDelegate {
        let completionHandlerState = Mutex<(@Sendable () -> Void)?>(nil)
        private let didFinish: @Sendable (BackgroundHttpClient.BackgroundTask) -> Void

        init(didFinish: @escaping @Sendable (BackgroundHttpClient.BackgroundTask) -> Void) {
            self.didFinish = didFinish
        }

        func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didFinishDownloadingTo location: URL
        ) {
            guard let identifier = session.configuration.identifier, let currentRequest = downloadTask.currentRequest, let currentURL = currentRequest.url else {
                return
            }
            do {
                let newFile = try RoundTripSupport.downloadDirectory()
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(currentURL.pathExtension)
                try FileManager.default.moveItem(at: location, to: newFile)
                let task = BackgroundHttpClient.BackgroundTask(sessionId: identifier, requestURL: currentURL, file: newFile)
                didFinish(task)
            } catch {
                RoundTripSupport.log(error)
            }
        }

        func urlSession(_: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
            guard RoundTripSupport.isDebugLoggingEnabled else {
                return
            }
            if let request = task.currentRequest,
               let response = task.response as? HTTPURLResponse {

                let status = response.statusCode

                let timeInSeconds = metrics.taskInterval.duration
                let timeAsString = RoundTripSupport.shortDuration(timeInSeconds)

                let totalBytes = metrics.transactionMetrics.reduce(Int64(0)) { source, taskMetrics -> Int64 in
                    source + taskMetrics.countOfResponseBodyBytesReceived + taskMetrics.countOfResponseHeaderBytesReceived
                }

                let totalByteAsString = RoundTripSupport.byteCount(totalBytes)

                let msg = if let query = request.url?.query {
                    "\(status) \(request.httpMethod ?? "???") \(request.url?.path ?? "/")?\(query) - \(totalByteAsString) - \(timeAsString)"
                } else {
                    "\(status) \(request.httpMethod ?? "???") \(request.url?.path ?? "/") - \(totalByteAsString) - \(timeAsString)"
                }
                RoundTripSupport.logDebug("Incoming Http Response: \(msg)")
            }
        }

        #if os(iOS) || os(watchOS)
            func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
                if let identifier = session.configuration.identifier {
                    RoundTripSupport.logDebug("Background URL Session \(identifier) will complete background transfers")
                }
                let completionHandler = completionHandlerState.withLock { $0 }
                completionHandler?()
            }
        #endif
    }

#endif
