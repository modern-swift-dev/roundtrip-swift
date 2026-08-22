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
        /// Thread safety: immutable request data is Sendable. A mutex protects state, and a recursive
        /// delivery lock serializes downstream calls with cancellation. The unchecked conformance
        /// covers Combine's reference-type protocol.
        class DownloadTaskSubscription<SubscriberType: Subscriber & Sendable>: Subscription, @unchecked Sendable where
            SubscriberType.Input == (url: URL, response: URLResponse),
            SubscriberType.Failure == any Error {

            private let destination: URL
            private let session: URLSession
            private let request: URLRequest
            private enum Phase: Equatable {
                case awaitingDemand
                case active
                case deliveringValue
                case terminated
            }

            private struct State {
                var subscriber: SubscriberType?
                var task: URLSessionDownloadTask?
                var phase = Phase.awaitingDemand
            }

            private let state: Mutex<State>
            private let deliveryLock = NSRecursiveLock()
            private let progress: Progress?
            private let pendingUnitCount: Int64
            public let combineIdentifier = CombineIdentifier()

            init(subscriber: SubscriberType, session: URLSession, request: URLRequest, destination: URL, progress: Progress? = nil, pendingUnitCount: Int64 = 1) {
                self.session = session
                self.request = request
                self.destination = destination
                self.progress = progress
                self.pendingUnitCount = pendingUnitCount
                state = Mutex(State(subscriber: subscriber))
            }

            public func request(_ demand: Subscribers.Demand) {
                guard demand > 0 else {
                    return
                }
                let task = state.withLock { state -> URLSessionDownloadTask? in
                    guard state.phase == .awaitingDemand else {
                        return nil
                    }
                    state.phase = .active
                    let task = session.downloadTask(with: request) { [weak self] tempFileURL, response, error in
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

                        guard let tempFileURL else {
                            self.deliverFailure(URLError(.fileDoesNotExist))
                            return
                        }

                        do {
                            try FileManager.default.moveItem(at: tempFileURL, to: self.destination)
                            self.deliver(url: self.destination, response: response)
                        } catch {
                            self.deliverFailure(error)
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
                deliveryLock.lock()
                let task = state.withLock { state -> URLSessionDownloadTask? in
                    guard state.phase != .terminated else {
                        return nil
                    }
                    state.phase = .terminated
                    state.subscriber = nil
                    let task = state.task
                    state.task = nil
                    return task
                }
                deliveryLock.unlock()
                task?.cancel()
            }

            private func deliver(url: URL, response: URLResponse) {
                deliveryLock.lock()
                defer {
                    deliveryLock.unlock()
                }
                guard let subscriber = beginValueDelivery() else {
                    return
                }
                _ = subscriber.receive((url: url, response: response))
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
