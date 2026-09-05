#if canImport(Combine)
    import Combine
    import Foundation
    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
    @testable import RoundTripREST
    import Testing

    @MainActor @Suite(.serialized) struct RESTWSSClientTests {
        private enum ObservedEvent: Sendable {
            case connected
            case disconnectedGoingAway
        }

        @Test func keepAliveConfigurationStoresValues() {
            let configuration = WSSClient.KeepAliveConfig(enabled: true, delay: 12.5)
            #expect(configuration.enabled)
            #expect(configuration.delay == 12.5)
        }

        @Test func delegatePublishesConnectionStateChanges() async throws {
            let (session, task) = try webSocketTask()
            defer { task.cancel(with: .goingAway, reason: nil); session.invalidateAndCancel() }
            let client = WSSClient(task: task, keepAlive: .init(enabled: true, delay: 30))
            let (events, continuation) = AsyncStream<ObservedEvent>.makeStream()
            let cancellable = client.event.sink { event in
                switch event {
                    case .connected:
                        continuation.yield(.connected)
                    case .disconnected(.goingAway):
                        continuation.yield(.disconnectedGoingAway)
                    default:
                        break
                }
            }
            defer {
                cancellable.cancel()
                continuation.finish()
            }

            let delegate = try #require(task.delegate as? any URLSessionWebSocketDelegate)
            delegate.urlSession?(session, webSocketTask: task, didOpenWithProtocol: nil)
            for await event in events {
                if case .connected = event {
                    break
                }
            }
            #expect(client.state.isConnected)

            delegate.urlSession?(session, webSocketTask: task, didCloseWith: .goingAway, reason: nil)
            for await event in events {
                if case .disconnectedGoingAway = event {
                    break
                }
            }
            if case .disconnected(.goingAway) = client.state {} else {
                Issue.record("Expected goingAway state")
            }
        }

        @Test func taskDelegateDoesNotRetainClient() throws {
            let (session, task) = try webSocketTask()
            defer { session.invalidateAndCancel() }
            var client: WSSClient? = WSSClient(task: task)
            let isReleased = { [weak client] in client == nil }

            client = nil

            #expect(isReleased())
        }

        @Test func disconnectedClientIgnoresOutboundActions() throws {
            let (session, task) = try webSocketTask()
            defer { task.cancel(with: .goingAway, reason: nil); session.invalidateAndCancel() }
            let client = WSSClient(task: task)
            var eventCount = 0
            let cancellable = client.event.sink { _ in eventCount += 1 }
            client.ping()
            client.send(uuid: UUID(), text: "hello")
            client.send(uuid: UUID(), binary: Data([1, 2, 3]))
            client.disconnect()
            #expect(!client.state.isConnected)
            #expect(eventCount == 0)
            cancellable.cancel()
        }

        private func webSocketTask() throws -> (URLSession, URLSessionWebSocketTask) {
            let session = URLSession(configuration: .ephemeral)
            let url = try #require(URL(string: "wss://example.com/socket"))
            return (session, session.webSocketTask(with: url))
        }
    }
#endif
