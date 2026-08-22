#if canImport(Combine)
    import Combine
    import Foundation
    import Synchronization

    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif

    public extension URLSession {

        /// Create a upload task publisher
        /// - parameter url: The URL for the upload
        /// - parameter file: The File to upload
        /// - parameter progress: The parent progress object to append the child to
        /// - returns: The Publisher
        func fileUploadTaskPublisher(for url: any URLRequestConvertible, file: URL, progress: Progress? = nil) throws -> URLSession.FileUploadTaskPublisher {
            let request = try url.buildRequest(baseUrl: nil, encoder: RoundTripSupport.makeJSONEncoder())

            return .init(request: request, file: file, session: self, progress: progress)
        }

        /// The Upload Task Publisher
        struct FileUploadTaskPublisher: Publisher {

            public typealias Output = (data: Data?, response: URLResponse)
            public typealias Failure = any Error

            public let file: URL
            public let request: URLRequest
            public let session: URLSession
            public let progress: Progress?

            public init(request: URLRequest, file: URL, session: URLSession, progress: Progress? = nil) {
                self.request = request
                self.session = session
                self.file = file
                self.progress = progress
            }

            public func receive<S: Subscriber & Sendable>(subscriber: S) where FileUploadTaskPublisher.Failure == S.Failure,
                FileUploadTaskPublisher.Output == S.Input {
                let subscription = FileUploadTaskSubscription(
                    subscriber: subscriber,
                    session: session,
                    request: request,
                    file: file,
                    progress: progress
                )
                subscriber.receive(subscription: subscription)
            }
        }

        /// The Upload Task Subscription
        ///
        /// Thread safety: immutable request data is Sendable, while a mutex protects task creation
        /// and cancellation. The unchecked conformance covers Combine's reference-type protocol.
        class FileUploadTaskSubscription<SubscriberType: Subscriber & Sendable>: Subscription, @unchecked Sendable where
            SubscriberType.Input == (data: Data?, response: URLResponse),
            SubscriberType.Failure == any Error {

            private let subscriber: SubscriberType
            private let file: URL
            private let session: URLSession
            private let request: URLRequest
            private struct State {
                var task: URLSessionUploadTask?
                var started = false
            }

            private let state = Mutex(State())
            private let progress: Progress?
            public let combineIdentifier = CombineIdentifier()

            init(subscriber: SubscriberType, session: URLSession, request: URLRequest, file: URL, progress: Progress? = nil) {
                self.subscriber = subscriber
                self.session = session
                self.request = request
                self.file = file
                self.progress = progress
            }

            public func request(_ demand: Subscribers.Demand) {
                guard demand > 0 else {
                    return
                }
                let task = state.withLock { state -> URLSessionUploadTask? in
                    guard !state.started else {
                        return nil
                    }
                    state.started = true
                    let task = session.uploadTask(with: request, fromFile: file) { [weak self] data, response, error in
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

                        _ = self.subscriber.receive((data: data, response: response))
                        self.subscriber.receive(completion: .finished)
                    }
                    state.task = task
                    return task
                }

                if let progress,
                   let size = RoundTripSupport.fileSize(at: file),
                   let taskProgress = task?.progress {
                    progress.addChild(taskProgress, withPendingUnitCount: size)
                }

                task?.resume()
            }

            public func cancel() {
                state.withLock { $0.task }?.cancel()
            }
        }
    }

#endif
