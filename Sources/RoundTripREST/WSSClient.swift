#if canImport(Combine)
    import Combine
    import Foundation
    import os

    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
    #if canImport(UIKit)
        import UIKit
    #endif
    #if canImport(AppKit)
        import AppKit
    #endif

    /// A WebSocket client supporting lifecycle pings and configurable keep-alive.
    ///
    /// WebSocket state, events, tasks, and lifecycle notifications are isolated to the main actor.
    @MainActor public final class WSSClient: NSObject {

        /// The possible events for a websocket.
        public enum WSSEvent {
            /// The socket connected.
            case connected

            /// The socket disconnected with a close code.
            case disconnected(URLSessionWebSocketTask.CloseCode)

            /// Receiving a message failed.
            case failure(any Error)

            /// A ping completed.
            case pingSent

            /// A ping failed.
            case pingFailed(any Error)

            /// A message completed, identified by its correlation ID.
            case messageSent(UUID)

            /// A message failed, identified by its correlation ID.
            case messageFailed(UUID, any Error)

            /// A text message arrived.
            case textMessageReceived(String)

            /// A binary message arrived.
            case binaryMessageReceived(Data)

            /// A message with an unsupported type arrived.
            case unsupportedMessageReceived
        }

        /// The possible states for a websocket.
        public enum WSSState {
            /// The socket is connected.
            case connected

            /// The socket is disconnected with a close code.
            case disconnected(URLSessionWebSocketTask.CloseCode)

            public var isConnected: Bool {
                switch self {
                    case .connected:
                        true
                    case .disconnected:
                        false
                }
            }
        }

        /// The keep-alive configuration.
        public struct KeepAliveConfig {
            var enabled: Bool
            var delay: TimeInterval

            /// Creates a keep-alive configuration.
            public init(enabled: Bool = false, delay: TimeInterval = 30.0) {
                self.enabled = enabled
                self.delay = delay
            }
        }

        private static let logger = Logger(subsystem: "RoundTripREST", category: "WebSocket")
        private let task: URLSessionWebSocketTask

        /// The current connection state and its publisher.
        @Published public private(set) var state: WSSState = .disconnected(.normalClosure)

        /// Publishes connection, message, and ping events.
        public private(set) var event = PassthroughSubject<WSSEvent, Never>()
        private(set) var keepAliveConfig: KeepAliveConfig

        private var keepAliveCancellable: AnyCancellable?
        private var listenCancellable: AnyCancellable?
        private var foregroundNotificationCancellable: AnyCancellable?

        /// Creates a WebSocket client.
        /// - Parameters:
        ///   - wssTask: The WebSocket task.
        ///   - keepAlive: The keep-alive configuration.
        public init(
            task wssTask: URLSessionWebSocketTask,
            keepAlive: KeepAliveConfig = .init(enabled: false, delay: 30.0)
        ) {
            task = wssTask
            keepAliveConfig = keepAlive
            super.init()
            task.delegate = WeakWebSocketDelegate(client: self)
            observeApplicationLifecycle()
        }

        deinit {
            task.cancel()
        }

        private func observeApplicationLifecycle() {
            #if canImport(UIKit) && !os(watchOS)
                foregroundNotificationCancellable = Publishers.Merge(
                    NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification),
                    NotificationCenter.default.publisher(for: UIScene.willDeactivateNotification)
                )
                .receive(on: RunLoop.main)
                .sink { @MainActor [weak self] _ in
                    self?.ping()
                }
            #elseif canImport(AppKit)
                foregroundNotificationCancellable = Publishers.Merge(
                    NotificationCenter.default.publisher(for: NSApplication.willBecomeActiveNotification),
                    NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)
                )
                .receive(on: RunLoop.main)
                .sink { @MainActor [weak self] _ in
                    self?.ping()
                }
            #endif
        }

        private func configureKeepAliveTimer() {
            stopKeepAlive()
            guard keepAliveConfig.enabled, keepAliveConfig.delay > 0 else {
                return
            }

            keepAliveCancellable = Timer.publish(
                every: keepAliveConfig.delay,
                on: .main,
                in: .default
            )
            .autoconnect()
            .sink { @MainActor [weak self] _ in
                self?.ping()
            }
        }

        private func stopKeepAlive() {
            keepAliveCancellable?.cancel()
            keepAliveCancellable = nil
        }

        private func stopListening() {
            listenCancellable?.cancel()
            listenCancellable = nil
        }

        /// Connects the websocket.
        public func connect() {
            guard !state.isConnected else {
                return
            }
            task.resume()
            listen()
        }

        /// Disconnects the websocket.
        public func disconnect(
            code: URLSessionWebSocketTask.CloseCode = .normalClosure,
            reason: Data? = nil
        ) {
            if state.isConnected {
                task.cancel(with: code, reason: reason)
            } else {
                task.cancel()
            }
            stopKeepAlive()
            stopListening()
        }

        private func listen() {
            stopListening()
            let listeningTask = Task { @MainActor [weak self, task] in
                while !Task.isCancelled {
                    do {
                        let message = try await task.receive()
                        try Task.checkCancellation()
                        self?.handle(message)
                    } catch is CancellationError {
                        break
                    } catch let error as URLError where error.code == .cancelled {
                        break
                    } catch where Task.isCancelled {
                        break
                    } catch {
                        Self.log(error)
                        self?.event.send(.failure(error))
                        break
                    }
                }
            }
            listenCancellable = AnyCancellable {
                listeningTask.cancel()
            }
        }

        private func handle(_ message: URLSessionWebSocketTask.Message) {
            switch message {
                case let .string(text):
                    Self.logger.debug("Received a text message")
                    event.send(.textMessageReceived(text))
                case let .data(binary):
                    Self.logger.debug("Received a binary message")
                    event.send(.binaryMessageReceived(binary))
                @unknown default:
                    Self.logger.debug("Received an unsupported message")
                    event.send(.unsupportedMessageReceived)
            }
        }

        private static func log(_ error: any Error) {
            logger.error("\(String(describing: error), privacy: .public)")
        }
    }

    public extension WSSClient {

        /// Sends a ping.
        func ping() {
            guard state.isConnected else {
                return
            }

            task.sendPing { [weak self] error in
                Task { @MainActor [weak self] in
                    if let error {
                        Self.log(error)
                        Self.logger.debug("Ping failed")
                        self?.event.send(.pingFailed(error))
                    } else {
                        Self.logger.debug("Ping sent")
                        self?.event.send(.pingSent)
                    }
                }
            }
        }

        /// Sends a text message.
        /// - Parameters:
        ///   - uuid: The identifier used to correlate the resulting event.
        ///   - text: The text to send.
        func send(uuid: UUID = .init(), text: String) {
            send(uuid: uuid, message: .string(text))
        }

        /// Sends a binary message.
        /// - Parameters:
        ///   - uuid: The identifier used to correlate the resulting event.
        ///   - binary: The data to send.
        func send(uuid: UUID = .init(), binary: Data) {
            send(uuid: uuid, message: .data(binary))
        }

        private func send(uuid: UUID, message: URLSessionWebSocketTask.Message) {
            guard state.isConnected else {
                return
            }

            task.send(message) { [weak self] error in
                Task { @MainActor [weak self] in
                    if let error {
                        Self.log(error)
                        Self.logger.debug("Message send failed")
                        self?.event.send(.messageFailed(uuid, error))
                    } else {
                        Self.logger.debug("Message sent")
                        self?.event.send(.messageSent(uuid))
                    }
                }
            }
        }
    }

    extension WSSClient: URLSessionWebSocketDelegate {

        public nonisolated func urlSession(
            _: URLSession,
            webSocketTask _: URLSessionWebSocketTask,
            didOpenWithProtocol _: String?
        ) {
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                state = .connected
                event.send(.connected)
                configureKeepAliveTimer()
                Self.logger.debug("Connected")
            }
        }

        public nonisolated func urlSession(
            _: URLSession,
            webSocketTask _: URLSessionWebSocketTask,
            didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
            reason _: Data?
        ) {
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                state = .disconnected(closeCode)
                event.send(.disconnected(closeCode))
                stopKeepAlive()
                stopListening()
                Self.logger.debug("Disconnected with \(closeCode.rawValue)")
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
