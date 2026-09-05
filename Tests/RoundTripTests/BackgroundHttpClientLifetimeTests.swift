#if !os(watchOS) && canImport(Combine)
    import Foundation
    @testable import RoundTrip
    import Synchronization
    import Testing

    @MainActor @Suite(.serialized) struct BackgroundHttpClientLifetimeTests {
        @Test(.timeLimit(.minutes(1)), arguments: [false, true])
        func releasingClientLetsTransferFinishUnlessExplicitlyCancelled(cancel: Bool) async throws {
            let (events, continuation) = AsyncStream<LifetimeEvent>.makeStream()
            LifetimeURLProtocol.events.withLock { $0 = continuation }
            defer {
                LifetimeURLProtocol.events.withLock { $0 = nil }
                continuation.finish()
            }
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [LifetimeURLProtocol.self]
            var client: BackgroundHttpClient? = BackgroundHttpClient(configuration: configuration)
            let isReleased = { [weak client] in client == nil }
            let session = try #require(client?.session)
            defer { session.invalidateAndCancel() }
            client?.completionHandler = { [probe = DelegateReleaseProbe(continuation: continuation)] in
                withExtendedLifetime(probe) {}
            }
            let url = try #require(URL(string: "https://example.com/background-lifetime"))
            let task = try #require(try client?.download(urlRequest: url))
            var iterator = events.makeAsyncIterator()
            guard case let .started(connection) = await iterator.next() else {
                Issue.record("Transfer did not start")
                return
            }

            client = nil
            #expect(isReleased())
            #expect(task.state == .running)

            if cancel {
                task.cancel()
            } else {
                connection.complete()
            }
            while let event = await iterator.next() {
                if case .delegateReleased = event {
                    break
                }
            }
            #expect(task.state == .completed)
            if cancel {
                #expect((task.error as? URLError)?.code == .cancelled)
            } else {
                #expect(task.error == nil)
            }
        }
    }

    private enum LifetimeEvent: Sendable {
        case started(LifetimeURLProtocol)
        case delegateReleased
    }

    private final class DelegateReleaseProbe: Sendable {
        let continuation: AsyncStream<LifetimeEvent>.Continuation

        init(continuation: AsyncStream<LifetimeEvent>.Continuation) {
            self.continuation = continuation
        }

        deinit { continuation.yield(.delegateReleased) }
    }

    private final class LifetimeURLProtocol: URLProtocol, @unchecked Sendable {
        static let events = Mutex<AsyncStream<LifetimeEvent>.Continuation?>(nil)

        override static func canInit(with request: URLRequest) -> Bool {
            true
        }

        override static func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            Self.events.withLock { $0 }?.yield(.started(self))
        }

        override func stopLoading() {}

        func complete() {
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) else {
                Issue.record("Invalid fixture request")
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data("download".utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }
#endif
