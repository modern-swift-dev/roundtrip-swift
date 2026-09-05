#if canImport(Combine)
    import Combine
    import Foundation
    @testable import RoundTrip
    import Synchronization
    import Testing

    struct DownloadSubscriptionCancellationTests {
        @Test func successfulCallbackAfterCancellationDoesNotMoveFile() throws {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let temporaryFile = directory.appendingPathComponent("temporary")
            let destination = directory.appendingPathComponent("destination")
            try Data([1, 2, 3]).write(to: temporaryFile)
            let session = DeferredDownloadSession()
            defer { session.invalidateAndCancel() }
            let url = try #require(URL(string: "https://example.com/download"))
            let subscription = URLSession.DownloadTaskSubscription(
                subscriber: CanceledDownloadSubscriber(), session: session,
                request: URLRequest(url: url), destination: destination
            )
            subscription.request(.max(1))
            subscription.cancel()
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            session.complete(at: temporaryFile, response: response)
            #expect(!FileManager.default.fileExists(atPath: destination.path))
            #expect(FileManager.default.fileExists(atPath: temporaryFile.path))
        }
    }

    private final class DeferredDownloadSession: URLSession, @unchecked Sendable {
        private let backing = URLSession(configuration: .ephemeral)

        override func invalidateAndCancel() {
            backing.invalidateAndCancel()
        }

        private typealias Completion = @Sendable (URL?, URLResponse?, (any Error)?) -> Void
        private let completion = Mutex<Completion?>(nil)

        override func downloadTask(with request: URLRequest, completionHandler: @escaping @Sendable (URL?, URLResponse?, (any Error)?) -> Void) -> URLSessionDownloadTask {
            completion.withLock { $0 = completionHandler }
            // A canceled task keeps this fixture independent of the network.
            let task = backing.downloadTask(with: request)
            task.cancel()
            return task
        }

        func complete(at file: URL, response: URLResponse) {
            let callback = completion.withLock { state in
                let callback = state
                state = nil
                return callback
            }
            callback?(file, response, nil)
        }
    }

    private final class CanceledDownloadSubscriber: Subscriber, Sendable {
        typealias Input = (url: URL, response: URLResponse)
        typealias Failure = any Error
        func receive(subscription: any Subscription) {}
        func receive(_ input: Input) -> Subscribers.Demand {
            Issue.record("Canceled download delivered a value")
            return .none
        }

        func receive(completion: Subscribers.Completion<any Error>) {
            Issue.record("Canceled download delivered completion")
        }
    }
#endif
