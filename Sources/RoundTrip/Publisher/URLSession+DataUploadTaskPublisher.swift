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
        /// - parameter data: The data to upload
        /// - parameter progress: The parent progress object to append the child to
        /// - returns: The Publisher
        func dataUploadTaskPublisher(for url: any URLRequestConvertible, data: Data, progress: Progress? = nil) throws -> URLSession.DataUploadTaskPublisher {
            let request = try url.buildRequest(baseUrl: nil, encoder: RoundTripSupport.makeJSONEncoder())
            return .init(request: request, data: data, session: self, progress: progress)
        }

        /// The Upload Task Publisher
        struct DataUploadTaskPublisher: Publisher {

            public typealias Output = (data: Data?, response: URLResponse)
            public typealias Failure = any Error

            public let data: Data
            public let request: URLRequest
            public let session: URLSession
            public let progress: Progress?

            public init(request: URLRequest, data: Data, session: URLSession, progress: Progress? = nil) {
                self.request = request
                self.session = session
                self.data = data
                self.progress = progress
            }

            public func receive<S: Subscriber & Sendable>(subscriber: S) where DataUploadTaskPublisher.Failure == S.Failure,
                DataUploadTaskPublisher.Output == S.Input {
                let subscription = DataUploadTaskSubscription(
                    subscriber: subscriber,
                    session: session,
                    request: request,
                    data: data,
                    progress: progress
                )
                subscriber.receive(subscription: subscription)
            }
        }

        /// The Upload Task Subscription
        ///
        /// Thread safety: immutable request data is Sendable, while a mutex protects task creation
        /// and cancellation. The unchecked conformance covers Combine's reference-type protocol.
        class DataUploadTaskSubscription<SubscriberType: Subscriber & Sendable>: Subscription, @unchecked Sendable where
            SubscriberType.Input == (data: Data?, response: URLResponse),
            SubscriberType.Failure == any Error {

            private let subscriber: SubscriberType
            private let data: Data
            private let session: URLSession
            private let request: URLRequest
            private struct State {
                var task: URLSessionUploadTask?
                var started = false
            }

            private let state = Mutex(State())
            private let progress: Progress?
            public let combineIdentifier = CombineIdentifier()

            init(subscriber: SubscriberType, session: URLSession, request: URLRequest, data: Data, progress: Progress? = nil) {
                self.subscriber = subscriber
                self.session = session
                self.request = request
                self.data = data
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
                    let task = session.uploadTask(with: request, from: data) { [weak self] data, response, error in
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

                if let taskProgress = task?.progress {
                    progress?.addChild(taskProgress, withPendingUnitCount: Int64(data.count))
                }
                task?.resume()
            }

            public func cancel() {
                state.withLock { $0.task }?.cancel()
            }
        }
    }

#endif
