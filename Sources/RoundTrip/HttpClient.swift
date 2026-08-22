#if canImport(Combine)
    import Combine
#endif
import Foundation
import Synchronization

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// A full-featured HTTP client that supports request adaptation, progress tracking, and
/// various types of HTTP operations including data tasks, uploads, downloads and websockets.
///
/// Example:
/// ```swift
/// let client = HttpClient()
/// let response = try await client.execute(request: myRequest)
/// ```
///
public final class HttpClient: Sendable {

    private struct State {
        var session: URLSession
        let configuration: URLSessionConfiguration
    }

    private let state: Mutex<State>

    /// The operation queue
    private let operationQueue: OperationQueue

    /// Initializer
    /// - parameter configuration: Defaults to `default`
    public init(configuration: URLSessionConfiguration = .default) {
        let dispatchQueue = DispatchQueue(label: "http-client-dispatch-queue", qos: .default)
        let queue = OperationQueue()
        queue.name = "http-client-operation-queue"
        queue.underlyingQueue = dispatchQueue
        queue.qualityOfService = .background
        queue.maxConcurrentOperationCount = OperationQueue.defaultMaxConcurrentOperationCount
        operationQueue = queue
        let session = URLSession(configuration: configuration, delegate: HttpClientDelegate(), delegateQueue: queue)
        state = Mutex(State(session: session, configuration: configuration))
    }

    private func currentSession() -> URLSession {
        state.withLock { state in
            state.session
        }
    }

    #if canImport(Combine)
        /// Creates a WebSocket client for a request.
        /// - Parameters:
        ///   - request: The request used to create the WebSocket task.
        ///   - keepAlive: The optional keep-alive timer configuration.
        /// - Returns: A main-actor-isolated WebSocket client.
        @MainActor public func webSocketClient(
            request: any URLRequestConvertible,
            keepAlive: WSSClient.KeepAliveConfig = .init(enabled: false, delay: 30.0)
        ) throws -> WSSClient {
            let request = try request.buildRequest(baseUrl: nil, encoder: RoundTripSupport.makeJSONEncoder())
            let task = currentSession().webSocketTask(with: request)
            return WSSClient(task: task, keepAlive: keepAlive)
        }
    #endif

    // MARK: - Execute
    /// Execute data task asynchronously
    /// - parameter request: The Request
    /// - returns: The api response
    /// - throws: An ApiError
    public func execute(request: any URLRequestConvertible) async throws -> ApiResponse {

        let request = try request.buildRequest(baseUrl: nil, encoder: RoundTripSupport.makeJSONEncoder())
        let rawResponse: (Data, URLResponse) = try await currentSession().data(for: request)
        return ApiResponse(data: rawResponse.0, response: rawResponse.1)
    }

    // Execute an `URLRequestConvertible` as a `URLSession.DataTaskPublisher`
    // - parameter request: The URLRequestConvertible to execute
    // - returns: The publisher for this task.
    #if canImport(Combine)
        public func execute(request: any URLRequestConvertible) throws -> AnyPublisher<ApiResponse, ApiError> {
            do {

                let request = try request.buildRequest(baseUrl: nil, encoder: RoundTripSupport.makeJSONEncoder())
                return currentSession()
                    .dataTaskPublisher(for: request)
                    .map { tuple in
                        ApiResponse(data: tuple.data, response: tuple.response)
                    }
                    .mapError { original in
                        ApiError.unknown(original)
                    }
                    .handleEvents(receiveCompletion: {
                        switch $0 {
                            case let .failure(error):
                                RoundTripSupport.log(error)
                            default:
                                break
                        }
                    }).eraseToAnyPublisher()
            } catch {
                return ApiError.requestEncodingFailed.fail()
            }
        }
    #endif

    // MARK: - Download
    /// Download a file
    ///
    /// - parameter request: The URLRequestConvertible to execute
    /// - parameter destination: The Place to put the file
    /// - parameter progress: The progress for this download
    /// - parameter pendingUnitCount: The progress value
    /// - returns: The publisher for this task.
    #if canImport(Combine)
        public func download(
            request: any URLRequestConvertible,
            destination: URL,
            progress: Progress? = nil,
            pendingUnitCount: Int64 = 1
        ) throws -> AnyPublisher<ApiResponse, ApiError> {
            do {
                return try currentSession().downloadTaskPublisher(
                    for: request,
                    destination: destination,
                    progress: progress,
                    pendingUnitCount: pendingUnitCount
                )
                .map { tuple in
                    ApiResponse(file: tuple.url, response: tuple.response)
                }
                .mapError { original in
                    ApiError.unknown(original)
                }
                .handleEvents(receiveCompletion: {
                    switch $0 {
                        case let .failure(error):
                            RoundTripSupport.log(error)
                        default:
                            break
                    }
                }).eraseToAnyPublisher()
            } catch {
                return ApiError.requestEncodingFailed.fail()
            }
        }
    #endif

    /// Execute download task asynchronously
    /// - parameter request: The Request
    /// - parameter destination: The destination file URL
    /// - parameter progress: The parent progress object for the transfer
    /// - returns: The api response
    /// - throws: An error if request construction, transfer, validation, or file movement fails.
    public func download(request: any URLRequestConvertible, to destination: URL, progress: Progress? = nil) async throws -> ApiResponse {

        let request = try request.buildRequest(baseUrl: nil, encoder: RoundTripSupport.makeJSONEncoder())
        let taskReference = URLSessionTaskReference()
        let rawResponse: (URL, URLResponse) = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = currentSession().downloadTask(with: request, completionHandler: { url, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let url else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                        return
                    }

                    guard let response = response as? HTTPURLResponse else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                        return
                    }

                    guard (200 ..< 300).contains(response.statusCode) else {
                        continuation.resume(throwing: ApiError.invalidStatusCode(response.statusCode))
                        return
                    }

                    do {
                        try FileManager.default.moveItem(at: url, to: destination)
                        continuation.resume(returning: (destination, response))
                    } catch {
                        do {
                            try FileManager.default.removeItem(at: url)
                        } catch {
                            RoundTripSupport.log(error)
                        }
                        continuation.resume(throwing: error)
                    }
                })
                taskReference.store(task)
                progress?.addChild(task.progress, withPendingUnitCount: NSURLSessionTransferSizeUnknown)
                task.resume()
            }
        } onCancel: {
            taskReference.cancel()
        }
        return ApiResponse(file: destination, response: rawResponse.1)
    }

    /// Execute upload task asynchronously
    /// - parameter request: The Request
    /// - parameter data: The source data
    /// - parameter progress: The parent progress object for the transfer
    /// - returns: The api response
    /// - throws: An error if request construction or transfer fails.
    public func upload(request: any URLRequestConvertible, data: Data, progress: Progress? = nil) async throws -> ApiResponse {
        let request = try request.buildRequest(baseUrl: nil, encoder: RoundTripSupport.makeJSONEncoder())
        let taskReference = URLSessionTaskReference()
        let rawResponse: (Data, URLResponse) = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = currentSession().uploadTask(with: request, from: data, completionHandler: { data, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    if let data, let response {
                        continuation.resume(returning: (data, response))
                        return
                    }

                    continuation.resume(throwing: URLError(.unknown))
                })

                taskReference.store(task)
                if let progress {
                    progress.totalUnitCount += Int64(data.count)
                    progress.addChild(task.progress, withPendingUnitCount: Int64(data.count))
                }

                task.resume()
            }
        } onCancel: {
            taskReference.cancel()
        }

        return ApiResponse(data: rawResponse.0, response: rawResponse.1)
    }

    // MARK: - Multipart File Upload

    /// Execute upload task asynchronously
    /// - parameter request: The Request
    /// - parameter body: The multipart data
    /// - parameter progress: The parent progress object for the transfer
    /// - returns: The api response
    /// - throws: An error if body creation, request construction, or transfer fails.
    public func multiPartUpload(request: any URLRequestConvertible, body: any MultipartBodyConvertible, progress: Progress? = nil) async throws -> ApiResponse {
        let requestBody = try body.multiPartBody(encoder: RoundTripSupport.makeJSONEncoder())
        defer {
            requestBody.cleanup()
        }

        let request = try request.buildRequest(baseUrl: nil, encoder: RoundTripSupport.makeJSONEncoder())
        let converted = requestBody.apply(request)
        let source = requestBody.url
        let taskReference = URLSessionTaskReference()
        let rawResponse: (Data, URLResponse) = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = currentSession().uploadTask(with: converted, fromFile: source, completionHandler: { data, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    if let data, let response {
                        continuation.resume(returning: (data, response))
                        return
                    }

                    continuation.resume(throwing: URLError(.unknown))
                })

                taskReference.store(task)
                if let progress, let size = RoundTripSupport.fileSize(at: source) {
                    progress.totalUnitCount += size
                    progress.addChild(task.progress, withPendingUnitCount: size)
                }

                task.resume()
            }
        } onCancel: {
            taskReference.cancel()
        }

        return ApiResponse(data: rawResponse.0, response: rawResponse.1)
    }

    /// Execute upload task asynchronously
    /// - parameter request: The Request
    /// - parameter source: The source file
    /// - parameter progress: The parent progress object for the transfer
    /// - returns: The api response
    /// - throws: An error if request construction or transfer fails.
    public func fileUpload(request: any URLRequestConvertible, from source: URL, progress: Progress? = nil) async throws -> ApiResponse {
        let request = try request.buildRequest(baseUrl: nil, encoder: RoundTripSupport.makeJSONEncoder())
        let taskReference = URLSessionTaskReference()
        let rawResponse: (Data, URLResponse) = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = currentSession().uploadTask(with: request, fromFile: source, completionHandler: { data, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    if let data, let response {
                        continuation.resume(returning: (data, response))
                        return
                    }

                    continuation.resume(throwing: URLError(.unknown))
                })

                taskReference.store(task)
                if let progress, let size = RoundTripSupport.fileSize(at: source) {
                    progress.totalUnitCount += size
                    progress.addChild(task.progress, withPendingUnitCount: size)
                }

                task.resume()
            }
        } onCancel: {
            taskReference.cancel()
        }

        return ApiResponse(data: rawResponse.0, response: rawResponse.1)
    }

    // MARK: - Cancel
    /// Invalidate session, and recreate it. Effectively cancelling all http requests
    /// that are in progress
    public func invalidate(recreate: Bool = false) {
        state.withLock { state in
            state.session.invalidateAndCancel()
            if recreate {
                state.session = URLSession(
                    configuration: state.configuration,
                    delegate: HttpClientDelegate(),
                    delegateQueue: operationQueue
                )
            }
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

/// Thread Safety: @unchecked Sendable because this delegate has no mutable state.
/// It only logs errors and metrics from URLSession callbacks.
public class HttpClientDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {

    public func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let error {
            let method = task.currentRequest?.httpMethod ?? "??"
            let url = task.currentRequest?.url?.path ?? "??"
            RoundTripSupport.log(error, message: "\(method) \(url)")
        }
    }

    // Log performance information for the application HTTP Request
    #if !os(Linux)
        public func urlSession(_: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
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
    #endif
}
