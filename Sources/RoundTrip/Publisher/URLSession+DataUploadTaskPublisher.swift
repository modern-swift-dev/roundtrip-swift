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
        /// Thread safety: immutable request data is Sendable. A mutex protects state, and a recursive
        /// delivery lock serializes downstream calls with cancellation. The unchecked conformance
        /// covers Combine's reference-type protocol.
        class DataUploadTaskSubscription<SubscriberType: Subscriber & Sendable>: Subscription, @unchecked Sendable where
            SubscriberType.Input == (data: Data?, response: URLResponse),
            SubscriberType.Failure == any Error {

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
                var data: Data?
                var task: URLSessionUploadTask?
                var phase = Phase.awaitingDemand
            }

            private let state: Mutex<State>
            private let deliveryLock = NSRecursiveLock()
            private let progress: Progress?
            public let combineIdentifier = CombineIdentifier()

            init(subscriber: SubscriberType, session: URLSession, request: URLRequest, data: Data, progress: Progress? = nil) {
                self.session = session
                self.progress = progress
                state = Mutex(State(subscriber: subscriber, request: request, data: data))
            }

            public func request(_ demand: Subscribers.Demand) {
                guard demand > 0 else {
                    return
                }

                let transfer = state.withLock { state -> (task: URLSessionUploadTask, byteCount: Int64)? in
                    guard state.phase == .awaitingDemand, let request = state.request, let data = state.data else {
                        return nil
                    }
                    state.phase = .active
                    let task = session.uploadTask(with: request, from: data) { [weak self] data, response, error in
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
                    state.data = nil
                    return (task, Int64(data.count))
                }

                if let transfer {
                    progress?.addChild(transfer.task.progress, withPendingUnitCount: transfer.byteCount)
                    transfer.task.resume()
                }
            }

            public func cancel() {
                deliveryLock.lock()
                let task = state.withLock { state -> URLSessionUploadTask? in
                    guard state.phase != .terminated else {
                        return nil
                    }
                    state.phase = .terminated
                    state.subscriber = nil
                    state.data = nil
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
