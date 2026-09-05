#if canImport(Combine)
    import Combine
    import Foundation
    @testable import RoundTrip
    import Synchronization
    import Testing

    struct UploadSubscriptionMemoryTests {
        @Test func cancellationReleasesBodyWhileSubscriptionIsRetained() throws {
            let released = ReleaseFlag()
            let session = URLSession(configuration: .ephemeral)
            defer { session.invalidateAndCancel() }
            let request = URLRequest(url: try #require(URL(string: "https://example.com/upload")))
            let subscription = URLSession.DataUploadTaskSubscription(
                subscriber: MemoryTestSubscriber(),
                session: session,
                request: request,
                data: makeBody(released: released)
            )

            #expect(!released.value.withLock { $0 })
            subscription.cancel()
            #expect(released.value.withLock { $0 })
            withExtendedLifetime(subscription) {}
        }

        @Test(arguments: [TransferKind.dataUpload, .fileUpload, .download])
        func cancellationReleasesRequestBody(kind: TransferKind) throws {
            let released = ReleaseFlag()
            let session = URLSession(configuration: .ephemeral)
            defer { session.invalidateAndCancel() }
            let url = try #require(URL(string: "https://example.com/transfer"))
            let subscription = makeSubscription(kind: kind, session: session, url: url, released: released)
            #expect(!released.value.withLock { $0 })
            subscription.cancel()
            #expect(released.value.withLock { $0 })
            withExtendedLifetime(subscription) {}
        }

        enum TransferKind: Sendable {
            case dataUpload
            case fileUpload
            case download
        }

        private func makeSubscription(kind: TransferKind, session: URLSession, url: URL, released: ReleaseFlag) -> any Subscription {
            var request = URLRequest(url: url)
            request.httpBody = makeBody(released: released)
            switch kind {
                case .dataUpload:
                    return URLSession.DataUploadTaskSubscription(subscriber: MemoryTestSubscriber(), session: session, request: request, data: Data())
                case .fileUpload:
                    return URLSession.FileUploadTaskSubscription(subscriber: MemoryTestSubscriber(), session: session, request: request, file: url)
                case .download:
                    return URLSession.DownloadTaskSubscription(subscriber: MemoryTestDownloadSubscriber(), session: session, request: request, destination: url)
            }
        }

        private func makeBody(released: ReleaseFlag) -> Data {
            let bytes = UnsafeMutableRawPointer.allocate(byteCount: 4096, alignment: 1)
            return Data(bytesNoCopy: bytes, count: 4096, deallocator: .custom { bytes, _ in
                bytes.deallocate()
                released.value.withLock { $0 = true }
            })
        }
    }

    private final class ReleaseFlag: Sendable {
        let value = Mutex(false)
    }

    private final class MemoryTestDownloadSubscriber: Subscriber, Sendable {
        typealias Input = (url: URL, response: URLResponse)
        typealias Failure = any Error
        func receive(subscription: any Subscription) {}
        func receive(_ input: Input) -> Subscribers.Demand {
            .none
        }

        func receive(completion: Subscribers.Completion<any Error>) {}
    }

    private final class MemoryTestSubscriber: Subscriber, Sendable {
        typealias Input = (data: Data?, response: URLResponse)
        typealias Failure = any Error
        func receive(subscription: any Subscription) {}
        func receive(_ input: Input) -> Subscribers.Demand {
            .none
        }

        func receive(completion: Subscribers.Completion<any Error>) {}
    }
#endif
