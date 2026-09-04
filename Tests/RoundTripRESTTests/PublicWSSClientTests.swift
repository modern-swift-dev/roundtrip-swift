#if canImport(Combine)
    import Combine
    import Foundation
    import RoundTripREST
    import Testing

    @MainActor struct PublicRESTWSSClientTests {
        @Test func externalConsumerCanObserveStateAndEvents() async throws {
            let session = URLSession(configuration: .ephemeral)
            let url = try #require(URL(string: "wss://example.com/socket"))
            let task = session.webSocketTask(with: url)
            defer {
                task.cancel()
                session.invalidateAndCancel()
            }
            let client = WSSClient(task: task)
            #expect(!client.state.isConnected)

            var observedStates: [Bool] = []
            let stateSubscription = client.$state.sink { observedStates.append($0.isConnected) }
            let (events, continuation) = AsyncStream<Bool>.makeStream()
            let eventSubscription = client.event.sink { event in
                if case .connected = event {
                    continuation.yield(true)
                }
            }
            defer {
                stateSubscription.cancel()
                eventSubscription.cancel()
                continuation.finish()
            }

            client.urlSession(session, webSocketTask: task, didOpenWithProtocol: nil)
            var iterator = events.makeAsyncIterator()
            #expect(await iterator.next() == true)
            #expect(client.state.isConnected)
            #expect(observedStates == [false, true])
        }
    }
#endif
