#if canImport(Combine)
    import Combine
    import Foundation
    import Synchronization

    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif

    public extension URLSession {

        /// Create a download task publisher
        /// - parameter url: The URLRequest for the download
        /// - parameter destination: The final placement of the file
        /// - parameter progress: The parent progress object to append the child to
        /// - parameter pendingUnitCount: The value of the download progress
        /// - returns: The Publisher
        /// - throws: An error if the request cannot be built.
        func downloadTaskPublisher(for url: any URLRequestConvertible, destination: URL, progress: Progress? = nil, pendingUnitCount: Int64 = 1) throws -> URLSession.DownloadTaskPublisher {
            let request = try url.buildRequest(baseUrl: nil, encoder: RoundTripSupport.makeJSONEncoder())

            return .init(request: request, destination: destination, session: self, progress: progress, pendingUnitCount: pendingUnitCount)
        }

        /// The Download Task Publisher
        struct DownloadTaskPublisher: Publisher {

            public typealias Output = (url: URL, response: URLResponse)
            public typealias Failure = any Error

            public let destination: URL
            public let request: URLRequest
            public let session: URLSession
            public let progress: Progress?
            public let pendingUnitCount: Int64

            public init(request: URLRequest, destination: URL, session: URLSession, progress: Progress? = nil, pendingUnitCount: Int64 = 1) {
                self.request = request
                self.session = session
                self.destination = destination
                self.progress = progress
                self.pendingUnitCount = pendingUnitCount
            }

            public func receive<S: Subscriber & Sendable>(subscriber: S) where DownloadTaskPublisher.Failure == S.Failure,
                DownloadTaskPublisher.Output == S.Input {
                let subscription = DownloadTaskSubscription(
                    subscriber: subscriber,
                    session: session,
                    request: request,
                    destination: destination,
                    progress: progress,
                    pendingUnitCount: pendingUnitCount
                )
                subscriber.receive(subscription: subscription)
            }
        }

        /// The Download Task Subscription
        ///
        /// Thread safety: immutable request data is Sendable, while a mutex protects task creation
        /// and cancellation. The unchecked conformance covers Combine's reference-type protocol.
        class DownloadTaskSubscription<SubscriberType: Subscriber & Sendable>: Subscription, @unchecked Sendable where
            SubscriberType.Input == (url: URL, response: URLResponse),
            SubscriberType.Failure == any Error {

            private let subscriber: SubscriberType
            private let destination: URL
            private let session: URLSession
            private let request: URLRequest
            private struct State {
                var task: URLSessionDownloadTask?
                var started = false
            }

            private let state = Mutex(State())
            private let progress: Progress?
            private let pendingUnitCount: Int64
            public let combineIdentifier = CombineIdentifier()

            init(subscriber: SubscriberType, session: URLSession, request: URLRequest, destination: URL, progress: Progress? = nil, pendingUnitCount: Int64 = 1) {
                self.subscriber = subscriber
                self.session = session
                self.request = request
                self.destination = destination
                self.progress = progress
                self.pendingUnitCount = pendingUnitCount
            }

            public func request(_ demand: Subscribers.Demand) {
                guard demand > 0 else {
                    return
                }
                let task = state.withLock { state -> URLSessionDownloadTask? in
                    guard !state.started else {
                        return nil
                    }
                    state.started = true
                    let task = session.downloadTask(with: request) { [weak self] tempFileURL, response, error in
                        guard let self else {
                            return
                        }
                        if let error {
                            self.subscriber.receive(completion: .failure(error))
                            return
                        }

                        guard let response else {
                            self.subscriber.receive(completion: .failure(URLError(.badServerResponse)))
                            return
                        }

                        guard let tempFileURL else {
                            self.subscriber.receive(completion: .failure(URLError(.fileDoesNotExist)))
                            return
                        }

                        do {
                            try FileManager.default.moveItem(at: tempFileURL, to: self.destination)
                            _ = self.subscriber.receive((url: self.destination, response: response))
                            self.subscriber.receive(completion: .finished)
                        } catch {
                            self.subscriber.receive(completion: .failure(error))
                        }
                    }
                    state.task = task
                    return task
                }

                if let taskProgress = task?.progress {
                    progress?.addChild(taskProgress, withPendingUnitCount: pendingUnitCount)
                }
                task?.resume()
            }

            public func cancel() {
                state.withLock { $0.task }?.cancel()
            }
        }
    }

#endif
