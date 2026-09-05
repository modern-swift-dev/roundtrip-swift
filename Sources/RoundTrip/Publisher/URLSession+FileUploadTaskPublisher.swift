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
        /// Thread safety: immutable request data is Sendable. A mutex protects state, and a recursive
        /// delivery lock serializes downstream calls with cancellation. The unchecked conformance
        /// covers Combine's reference-type protocol.
        class FileUploadTaskSubscription<SubscriberType: Subscriber & Sendable>: Subscription, @unchecked Sendable where
            SubscriberType.Input == (data: Data?, response: URLResponse),
            SubscriberType.Failure == any Error {

            private let file: URL
            private let session: URLSession
            private enum Phase: Equatable {
                case awaitingDemand
                case active
                case deliveringValue
                case terminated
            }

            private struct State {
                var subscriber: SubscriberType?
                var request: URLRequest?
                var task: URLSessionUploadTask?
                var phase = Phase.awaitingDemand
            }

            private let state: Mutex<State>
            private let deliveryLock = NSRecursiveLock()
            private let progress: Progress?
            public let combineIdentifier = CombineIdentifier()

            init(subscriber: SubscriberType, session: URLSession, request: URLRequest, file: URL, progress: Progress? = nil) {
                self.session = session
                self.file = file
                self.progress = progress
                state = Mutex(State(subscriber: subscriber, request: request))
            }

            public func request(_ demand: Subscribers.Demand) {
                guard demand > 0 else {
                    return
                }
                let task = state.withLock { state -> URLSessionUploadTask? in
                    guard state.phase == .awaitingDemand, let request = state.request else {
                        return nil
                    }
                    state.phase = .active
                    let task = session.uploadTask(with: request, fromFile: file) { [weak self] data, response, error in
                        guard let self else {
                            return
                        }
                        if let error {
                            self.deliverFailure(error)
                            return
                        }

                        guard let response else {
                            self.deliverFailure(URLError(.badServerResponse))
                            return
                        }

                        self.deliver(data: data, response: response)
                    }
                    state.task = task
                    state.request = nil
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
                deliveryLock.lock()
                let task = state.withLock { state -> URLSessionUploadTask? in
                    guard state.phase != .terminated else {
                        return nil
                    }
                    state.phase = .terminated
                    state.subscriber = nil
                    state.request = nil
                    let task = state.task
                    state.task = nil
                    return task
                }
                deliveryLock.unlock()
                task?.cancel()
            }

            private func deliver(data: Data?, response: URLResponse) {
                deliveryLock.lock()
                defer {
                    deliveryLock.unlock()
                }
                guard let subscriber = beginValueDelivery() else {
                    return
                }
                _ = subscriber.receive((data: data, response: response))
                takeSubscriberForFinishedDelivery()?.receive(completion: .finished)
            }

            private func deliverFailure(_ error: any Error) {
                deliveryLock.lock()
                defer {
                    deliveryLock.unlock()
                }
                takeSubscriberForTerminalDelivery()?.receive(completion: .failure(error))
            }

            private func takeSubscriberForTerminalDelivery() -> SubscriberType? {
                state.withLock { state in
                    guard state.phase == .active else {
                        return nil
                    }
                    state.phase = .terminated
                    state.task = nil
                    let subscriber = state.subscriber
                    state.subscriber = nil
                    return subscriber
                }
            }

            private func beginValueDelivery() -> SubscriberType? {
                state.withLock { state in
                    guard state.phase == .active else {
                        return nil
                    }
                    state.phase = .deliveringValue
                    return state.subscriber
                }
            }

            private func takeSubscriberForFinishedDelivery() -> SubscriberType? {
                state.withLock { state in
                    guard state.phase == .deliveringValue else {
                        return nil
                    }
                    state.phase = .terminated
                    state.task = nil
                    let subscriber = state.subscriber
                    state.subscriber = nil
                    return subscriber
                }
            }
        }
    }

#endif
