#if canImport(Combine)
    import Combine
    import Foundation
    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
    @testable import RoundTrip
    import Testing

    @MainActor @Suite(.serialized) struct WSSClientTests {

        @Test func keepAliveConfigStoresEnabledAndDelay() {
            let config = WSSClient.KeepAliveConfig(enabled: true, delay: 12.5)

            #expect(config.enabled)
            #expect(config.delay == 12.5)
        }

        @Test func delegateOpenAndClosePublishEventsAndUpdateState() async throws {
            let (session, task) = try makeWebSocketTask()
            defer {
                task.cancel(with: .goingAway, reason: nil)
                session.invalidateAndCancel()
            }

            let client = WSSClient(task: task, keepAlive: .init(enabled: true, delay: 30))
            var events: [String] = []
            await confirmation("delegate callbacks", expectedCount: 2) { eventReceived in
                let (eventStream, continuation) = AsyncStream<String>.makeStream()
                let cancellable = client.event.sink { event in
                    continuation.yield(label(for: event))
                }
                defer {
                    cancellable.cancel()
                    continuation.finish()
                }

                client.urlSession(session, webSocketTask: task, didOpenWithProtocol: nil)
                eventLoop: for await eventLabel in eventStream {
                    events.append(eventLabel)
                    switch eventLabel {
                        case "connected":
                            eventReceived()
                            client.urlSession(session, webSocketTask: task, didCloseWith: .goingAway, reason: nil)
                        case "disconnected:goingAway":
                            eventReceived()
                            break eventLoop
                        default:
                            break
                    }
                }
            }
            let isDisconnectedWithGoingAway = if case .disconnected(.goingAway) = client.state {
                true
            } else {
                false
            }
            #expect(isDisconnectedWithGoingAway)
            #expect(events == ["connected", "disconnected:goingAway"])
        }

        @Test func disconnectedClientIgnoresOutboundActions() throws {
            let (session, task) = try makeWebSocketTask()
            defer {
                task.cancel(with: .goingAway, reason: nil)
                session.invalidateAndCancel()
            }

            let client = WSSClient(task: task)
            var events: [String] = []
            let cancellable = client.event.sink { event in
                events.append(label(for: event))
            }

            let textId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
            let binaryId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))

            client.ping()
            client.send(uuid: textId, text: "hello")
            client.send(uuid: binaryId, binary: Data([1, 2, 3]))
            client.disconnect()

            #expect(!client.state.isConnected)
            #expect(events.isEmpty)

            _ = cancellable
        }

        private func makeWebSocketTask() throws -> (URLSession, URLSessionWebSocketTask) {
            let session = URLSession(configuration: .ephemeral)
            let url = try #require(URL(string: "wss://example.com/socket"))
            return (session, session.webSocketTask(with: url))
        }

        private func label(for event: WSSClient.WSSEvent) -> String {
            switch event {
                case .connected:
                    "connected"
                case let .disconnected(code):
                    "disconnected:\(label(for: code))"
                case .failure:
                    "failure"
                case .pingSent:
                    "pingSent"
                case .pingFailed:
                    "pingFailed"
                case let .messageSent(id):
                    "messageSent:\(id.uuidString)"
                case let .messageFailed(id, _):
                    "messageFailed:\(id.uuidString)"
                case let .textMessageReceived(text):
                    "text:\(text)"
                case let .binaryMessageReceived(data):
                    "binary:\(data.count)"
                case .unsupportedMessageReceived:
                    "unsupported"
            }
        }

        private func label(for code: URLSessionWebSocketTask.CloseCode) -> String {
            switch code {
                case .goingAway:
                    "goingAway"
                case .normalClosure:
                    "normalClosure"
                default:
                    "\(code.rawValue)"
            }
        }
    }

#endif
