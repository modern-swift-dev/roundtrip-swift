#if canImport(Combine)
    import Combine
    import Foundation

    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif

    /// A WebSocket client implementation supporting explicit connection control and keep-alive.
    /// Provides a Combine-based interface for WebSocket events.
    ///
    /// Example:
    /// ```swift
    /// let client = try httpClient.webSocketClient(request: wsRequest)
    /// client.event.sink { event in
    ///     // Handle WebSocket events
    /// }
    /// client.connect()
    /// ```
    ///
    /// WebSocket state, events, and task lifetimes are isolated to the main actor.
    @MainActor public final class WSSClient: NSObject {

        /// The possible events for a websocket
        public enum WSSEvent {

            /// Connect
            case connected

            /// Disconnected with specified close code
            case disconnected(URLSessionWebSocketTask.CloseCode)

            /// A failure
            case failure(any Error)

            /// Successfully sent a ping
            case pingSent

            /// Failed to send ping
            case pingFailed(any Error)

            /// Successfully sent message
            case messageSent(UUID)

            /// Failed to send message
            case messageFailed(UUID, any Error)

            /// Text Message received
            case textMessageReceived(String)

            /// Binary message received
            case binaryMessageReceived(Data)

            /// Unsupported message type received
            case unsupportedMessageReceived
        }

        /// The possible events for a websocket
        public enum WSSState {

            /// Connect
            case connected

            /// Disconnected with specified close code
            case disconnected(URLSessionWebSocketTask.CloseCode)

            public var isConnected: Bool {
                switch self {
                    case .connected:
                        true
                    default:
                        false
                }
            }
        }

        /// The Keep Alive Configuration
        public struct KeepAliveConfig {

            /// Enabled?
            public var enabled: Bool

            /// Delay for the keep-alive
            public var delay: TimeInterval

            /// Initializer
            public init(enabled: Bool = false, delay: TimeInterval = 30.0) {
                self.enabled = enabled
                self.delay = delay
            }
        }

        /// The `URLSessionWebSocketTask`
        private let task: URLSessionWebSocketTask

        /// The current state of the web-socket
        @Published public private(set) var state: WSSState = .disconnected(.normalClosure)

        /// The events
        public private(set) var event: PassthroughSubject<WSSEvent, Never> = .init()

        /// THe Keep Alive Config
        public private(set) var keepAliveConfig: KeepAliveConfig

        /// The Keep Alive Cancellable
        private var keepAliveCancellable: AnyCancellable?

        /// The Listen Cancellable
        private var listenTask: Task<Void, Never>?

        /// Initializer
        /// - parameter wssTask: The WebSocket task
        /// - parameter keepAlive: The keep-alive timer configuration
        public init(task wssTask: URLSessionWebSocketTask, keepAlive: KeepAliveConfig = .init(enabled: false, delay: 30.0)) {
            task = wssTask
            keepAliveConfig = keepAlive
            super.init()
            task.delegate = WeakWebSocketDelegate(client: self)
        }

        deinit {
            listenTask?.cancel()
            task.cancel()
        }

        private func stopListening() {
            listenTask?.cancel()
            listenTask = nil
        }
    }

    // MARK: - Message Methods
    public extension WSSClient {

        private func configureKeepAliveTimer() {
            keepAliveCancellable?.cancel()
            keepAliveCancellable = nil
            if keepAliveConfig.enabled, keepAliveConfig.delay > 0.0 {
                keepAliveCancellable = Timer.publish(
                    every: keepAliveConfig.delay,
                    tolerance: nil,
                    on: RunLoop.main,
                    in: .default
                )
                .autoconnect()
                .receive(on: RunLoop.main)
                .sink(receiveValue: { [weak self] _ in
                    self?.ping()
                })
            }
        }

        private func stopKeepAlive() {
            keepAliveCancellable?.cancel()
            keepAliveCancellable = nil
        }
    }

    // MARK: - Message Methods
    public extension WSSClient {

        /// Connect the websocket
        func connect() {
            guard !state.isConnected, listenTask == nil else {
                return
            }
            task.resume()
            listen()
        }

        /// Disconnect from the websocket
        func disconnect(code: URLSessionWebSocketTask.CloseCode = .normalClosure, reason: Data? = nil) {
            if state.isConnected {
                task.cancel(with: code, reason: reason)
            } else {
                task.cancel()
            }
            stopKeepAlive()
            stopListening()
        }

        /// Wait for the next full message
        private func listen() {
            listenTask = Task { @MainActor [weak self, task] in
                defer {
                    // A canceled listener may have already been replaced by connect().
                    if !Task.isCancelled {
                        self?.listenTask = nil
                    }
                }
                do {
                    while !Task.isCancelled {
                        let message = try await task.receive()
                        try Task.checkCancellation()
                        guard self != nil else {
                            return
                        }
                        self?.handle(message)
                    }
                } catch is CancellationError {
                    return
                } catch let error as URLError where error.code == .cancelled {
                    return
                } catch where Task.isCancelled {
                    return
                } catch {
                    self?.event.send(.failure(error))
                }
            }
        }

        private func handle(_ message: URLSessionWebSocketTask.Message) {
            switch message {
                case let .string(text):
                    event.send(.textMessageReceived(text))
                case let .data(binary):
                    event.send(.binaryMessageReceived(binary))
                @unknown default:
                    event.send(.unsupportedMessageReceived)
            }
        }
    }

    // MARK: - Message Methods
    public extension WSSClient {

        /// Send a ping
        func ping() {
            guard state.isConnected else {
                return
            }

            task.sendPing(pongReceiveHandler: { [weak self] error in
                Task { @MainActor [weak self] in
                    if let error {
                        self?.event.send(.pingFailed(error))
                    } else {
                        self?.event.send(.pingSent)
                    }
                }
            })
        }

        /// Send string data on the websocket
        /// - parameter uuid: The UUID for this message. More for debugging than actual function
        /// - parameter text: The text to send
        func send(uuid: UUID = .init(), text: String) {
            guard state.isConnected else {
                return
            }

            task.send(.string(text), completionHandler: { [weak self] error in
                Task { @MainActor [weak self] in
                    if let error {
                        self?.event.send(.messageFailed(uuid, error))
                    } else {
                        self?.event.send(.messageSent(uuid))
                    }
                }
            })
        }

        /// Send binary data on the websocket
        /// - parameter uuid: The UUID for this message. More for debugging than actual function
        /// - parameter binary: The binary data to send
        func send(uuid: UUID = .init(), binary: Data) {
            guard state.isConnected else {
                return
            }

            task.send(.data(binary), completionHandler: { [weak self] error in
                Task { @MainActor [weak self] in
                    if let error {
                        self?.event.send(.messageFailed(uuid, error))
                    } else {
                        self?.event.send(.messageSent(uuid))
                    }
                }
            })
        }
    }

    // MARK: - URLSessionDelegate
    extension WSSClient: URLSessionWebSocketDelegate {

        public nonisolated func urlSession(
            _: URLSession,
            webSocketTask _: URLSessionWebSocketTask,
            didOpenWithProtocol _: String?
        ) {
            Task { @MainActor [weak self] in
                self?.state = .connected
                self?.event.send(.connected)
                self?.configureKeepAliveTimer()
            }
        }

        public nonisolated func urlSession(
            _: URLSession,
            webSocketTask _: URLSessionWebSocketTask,
            didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
            reason _: Data?
        ) {
            Task { @MainActor [weak self] in
                self?.state = .disconnected(closeCode)
                self?.event.send(.disconnected(closeCode))
                self?.stopKeepAlive()
                self?.stopListening()
            }
        }
    }

    /// URLSession tasks retain their delegates, so the proxy must not retain the client.
    @MainActor private final class WeakWebSocketDelegate: NSObject, URLSessionWebSocketDelegate {
        private weak var client: WSSClient?

        init(client: WSSClient) {
            self.client = client
        }

        nonisolated func urlSession(
            _ session: URLSession,
            webSocketTask: URLSessionWebSocketTask,
            didOpenWithProtocol protocolName: String?
        ) {
            Task { @MainActor in
                client?.urlSession(session, webSocketTask: webSocketTask, didOpenWithProtocol: protocolName)
            }
        }

        nonisolated func urlSession(
            _ session: URLSession,
            webSocketTask: URLSessionWebSocketTask,
            didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
            reason: Data?
        ) {
            Task { @MainActor in
                client?.urlSession(session, webSocketTask: webSocketTask, didCloseWith: closeCode, reason: reason)
            }
        }
    }

#endif
