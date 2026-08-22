#if !os(watchOS)
    import Combine
    import Foundation
    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
    import RoundTrip
    import Synchronization
    import Testing

    @Suite(.serialized) struct HttpClientCancellationTests {

        @Test(.timeLimit(.minutes(1))) func cancellingDownloadCancelsURLSessionTask() async {
            let lifecycle = StalledURLProtocol.prepare()
            let destination = temporaryURL(named: "cancelled-download")
            defer { removeIfPresent(destination) }
            let client = HttpClient(configuration: stalledConfiguration())
            let operation = Task {
                try await client.download(request: try request(), to: destination)
            }

            await lifecycle.waitUntilStarted()
            operation.cancel()

            await lifecycle.waitUntilStopped()
            await expectCancellation(from: operation)
        }

        @Test(.timeLimit(.minutes(1))) func cancellingDataUploadCancelsURLSessionTask() async {
            let lifecycle = StalledURLProtocol.prepare()
            let client = HttpClient(configuration: stalledConfiguration())
            let operation = Task {
                try await client.upload(request: try request(method: "POST"), data: Data("payload".utf8))
            }

            await lifecycle.waitUntilStarted()
            operation.cancel()

            await lifecycle.waitUntilStopped()
            await expectCancellation(from: operation)
        }

        @Test(.timeLimit(.minutes(1))) func cancellingMultipartUploadCancelsURLSessionTask() async {
            let lifecycle = StalledURLProtocol.prepare()
            let client = HttpClient(configuration: stalledConfiguration())
            let operation = Task {
                let builder = try #require(try MultipartBody.Builder())
                builder.addPart(name: "field", part: .init(name: "field", text: "value"))
                let body = try builder.build()
                return try await client.multiPartUpload(request: try request(method: "POST"), body: body)
            }

            await lifecycle.waitUntilStarted()
            operation.cancel()

            await lifecycle.waitUntilStopped()
            await expectCancellation(from: operation)
        }

        @Test(.timeLimit(.minutes(1))) func cancellingFileUploadCancelsURLSessionTask() async throws {
            let lifecycle = StalledURLProtocol.prepare()
            let source = temporaryURL(named: "cancelled-upload")
            try Data("payload".utf8).write(to: source)
            defer { removeIfPresent(source) }
            let client = HttpClient(configuration: stalledConfiguration())
            let operation = Task {
                try await client.fileUpload(request: try request(method: "POST"), from: source)
            }

            await lifecycle.waitUntilStarted()
            operation.cancel()

            await lifecycle.waitUntilStopped()
            await expectCancellation(from: operation)
        }

        @Test(.timeLimit(.minutes(1))) func downloadPublisherReleasesSubscriberOnCancellation() async throws {
            let lifecycle = StalledURLProtocol.prepare()
            let destination = temporaryURL(named: "publisher-download")
            defer { removeIfPresent(destination) }
            let session = URLSession(configuration: stalledConfiguration())
            let publisher = try session.downloadTaskPublisher(
                for: request(),
                destination: destination
            )

            await expectCancellationReleasesSubscriber(publisher, lifecycle: lifecycle)
        }

        @Test(.timeLimit(.minutes(1))) func dataUploadPublisherReleasesSubscriberOnCancellation() async throws {
            let lifecycle = StalledURLProtocol.prepare()
            let session = URLSession(configuration: stalledConfiguration())
            let publisher = try session.dataUploadTaskPublisher(
                for: request(method: "POST"),
                data: Data("payload".utf8)
            )

            await expectCancellationReleasesSubscriber(publisher, lifecycle: lifecycle)
        }

        @Test(.timeLimit(.minutes(1))) func fileUploadPublisherReleasesSubscriberOnCancellation() async throws {
            let lifecycle = StalledURLProtocol.prepare()
            let source = temporaryURL(named: "publisher-upload")
            try Data("payload".utf8).write(to: source)
            defer { removeIfPresent(source) }
            let session = URLSession(configuration: stalledConfiguration())
            let publisher = try session.fileUploadTaskPublisher(
                for: request(method: "POST"),
                file: source
            )

            await expectCancellationReleasesSubscriber(publisher, lifecycle: lifecycle)
        }

        @Test(.timeLimit(.minutes(1))) func downloadPublisherSuppressesCompletionAfterReentrantCancellation() async throws {
            let destination = temporaryURL(named: "reentrant-download")
            defer { removeIfPresent(destination) }
            let session = URLSession(configuration: completingConfiguration())
            let publisher = try session.downloadTaskPublisher(
                for: request(),
                destination: destination
            )

            await expectReentrantCancellationSuppressesCompletion(publisher)
        }

        @Test(.timeLimit(.minutes(1))) func dataUploadPublisherSuppressesCompletionAfterReentrantCancellation() async throws {
            let session = URLSession(configuration: completingConfiguration())
            let publisher = try session.dataUploadTaskPublisher(
                for: request(method: "POST"),
                data: Data("payload".utf8)
            )

            await expectReentrantCancellationSuppressesCompletion(publisher)
        }

        @Test(.timeLimit(.minutes(1))) func fileUploadPublisherSuppressesCompletionAfterReentrantCancellation() async throws {
            let source = temporaryURL(named: "reentrant-upload")
            try Data("payload".utf8).write(to: source)
            defer { removeIfPresent(source) }
            let session = URLSession(configuration: completingConfiguration())
            let publisher = try session.fileUploadTaskPublisher(
                for: request(method: "POST"),
                file: source
            )

            await expectReentrantCancellationSuppressesCompletion(publisher)
        }

        private func request(method: String = "GET") throws -> URLRequest {
            let url = try #require(URL(string: "https://cancellation.example.com/transfer/\(UUID().uuidString)"))
            var request = URLRequest(url: url)
            request.httpMethod = method
            return request
        }

        private func stalledConfiguration() -> URLSessionConfiguration {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [StalledURLProtocol.self]
            return configuration
        }

        private func completingConfiguration() -> URLSessionConfiguration {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [CompletingURLProtocol.self]
            return configuration
        }

        private func temporaryURL(named name: String) -> URL {
            FileManager.default.temporaryDirectory
                .appendingPathComponent("roundtrip-\(name)-\(UUID().uuidString)")
        }

        private func removeIfPresent(_ url: URL) {
            guard FileManager.default.fileExists(atPath: url.path) else {
                return
            }
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                Issue.record("Failed to remove temporary file: \(error)")
            }
        }

        private func expectCancellation(from operation: Task<ApiResponse, any Error>) async {
            do {
                _ = try await operation.value
                Issue.record("Expected the transfer to throw cancellation")
            } catch is CancellationError {
                return
            } catch let error as URLError {
                #expect(error.code == .cancelled)
            } catch {
                Issue.record("Expected cancellation, received \(error)")
            }
        }

        private func expectCancellationReleasesSubscriber<P: Publisher>(
            _ publisher: P,
            lifecycle: StalledURLProtocol.Lifecycle
        ) async where P.Failure == any Error {
            let observation = PublisherObservation()
            var token: PublisherLifetimeToken? = .init()
            let weakToken = WeakBox(token)
            let cancellable = publisher
                .handleEvents(receiveCancel: {
                    observation.markCancellationStarted()
                })
                .sink(
                    receiveCompletion: { [token] _ in
                        _ = token
                        observation.recordCompletion()
                    },
                    receiveValue: { [token] _ in
                        _ = token
                        observation.recordValue()
                    }
                )

            await lifecycle.waitUntilStarted()
            cancellable.cancel()
            token = nil

            await lifecycle.waitUntilStopped()
            #expect(observation.counts == .zero)
            #expect(observation.signalsStartedAfterCancellation == 0)
            #expect(weakToken.value == nil)
        }

        private func expectReentrantCancellationSuppressesCompletion<P: Publisher>(
            _ publisher: P
        ) async where P.Failure == any Error {
            let subscriber = ReentrantCancellationSubscriber<P.Output>()
            publisher.receive(subscriber: subscriber)

            await subscriber.waitUntilValueReceived()
            await Task.yield()

            #expect(subscriber.counts.values == 1)
            #expect(subscriber.counts.completions == 0)
        }
    }

    private final class PublisherLifetimeToken: Sendable {}

    private final class WeakBox<Value: AnyObject> {
        weak var value: Value?

        init(_ value: Value?) {
            self.value = value
        }
    }

    private final class PublisherObservation: Sendable {
        struct Counts: Equatable, Sendable {
            var values = 0
            var completions = 0

            static let zero = Counts()
        }

        private let state = Mutex(Counts())
        private let cancellationState = Mutex(
            (started: false, signalsStartedAfterStart: 0)
        )

        var counts: Counts {
            state.withLock { $0 }
        }

        var signalsStartedAfterCancellation: Int {
            cancellationState.withLock { $0.signalsStartedAfterStart }
        }

        func markCancellationStarted() {
            cancellationState.withLock { $0.started = true }
        }

        func recordValue() {
            recordSignalStart()
            state.withLock { $0.values += 1 }
        }

        func recordCompletion() {
            recordSignalStart()
            state.withLock { $0.completions += 1 }
        }

        private func recordSignalStart() {
            cancellationState.withLock {
                if $0.started {
                    $0.signalsStartedAfterStart += 1
                }
            }
        }
    }

    /// Combine can call this subscriber from a URLSession callback. A mutex protects its state.
    private final class ReentrantCancellationSubscriber<Input>: Subscriber, @unchecked Sendable {
        typealias Failure = any Error

        /// The subscriber's mutex protects storage and retrieval of the Combine subscription.
        private struct SendableSubscription: @unchecked Sendable {
            let value: any Subscription
        }

        private struct State {
            var subscription: SendableSubscription?
            var counts = PublisherObservation.Counts.zero
        }

        private let state = Mutex(State())
        private let valueReceived: AsyncStream<Void>
        private let valueReceivedContinuation: AsyncStream<Void>.Continuation

        var counts: PublisherObservation.Counts {
            state.withLock { $0.counts }
        }

        init() {
            (valueReceived, valueReceivedContinuation) = AsyncStream<Void>.makeStream()
        }

        func receive(subscription: any Subscription) {
            state.withLock {
                $0.subscription = SendableSubscription(value: subscription)
            }
            subscription.request(.max(1))
        }

        func receive(_: Input) -> Subscribers.Demand {
            let subscription = state.withLock { state in
                state.counts.values += 1
                return state.subscription
            }
            subscription?.value.cancel()
            valueReceivedContinuation.yield()
            valueReceivedContinuation.finish()
            return .none
        }

        func receive(completion _: Subscribers.Completion<any Error>) {
            state.withLock { $0.counts.completions += 1 }
        }

        func waitUntilValueReceived() async {
            for await _ in valueReceived {
                return
            }
            Issue.record("The publisher did not emit its value")
        }
    }

    /// URLProtocol owns its callback threading and this stub has no mutable state.
    private class CompletingURLProtocol: URLProtocol, @unchecked Sendable {
        override class func canInit(with _: URLRequest) -> Bool {
            true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            guard let url = request.url,
                  let response = HTTPURLResponse(
                      url: url,
                      statusCode: 200,
                      httpVersion: nil,
                      headerFields: nil
                  ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data("response".utf8))
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    /// URLProtocol owns its callback threading. Static observer state is protected by a mutex.
    private class StalledURLProtocol: URLProtocol, @unchecked Sendable {
        struct Lifecycle: Sendable {
            let started: AsyncStream<Void>
            let stopped: AsyncStream<Void>

            func waitUntilStarted() async {
                for await _ in started {
                    return
                }
                Issue.record("The URL loading task did not start")
            }

            func waitUntilStopped() async {
                for await _ in stopped {
                    return
                }
                Issue.record("The URL loading task was not cancelled")
            }
        }

        private struct State: Sendable {
            var started: AsyncStream<Void>.Continuation?
            var stopped: AsyncStream<Void>.Continuation?
        }

        private static let state = Mutex(State())

        static func prepare() -> Lifecycle {
            let (started, startedContinuation) = AsyncStream<Void>.makeStream()
            let (stopped, stoppedContinuation) = AsyncStream<Void>.makeStream()
            state.withLock {
                $0.started?.finish()
                $0.stopped?.finish()
                $0.started = startedContinuation
                $0.stopped = stoppedContinuation
            }
            return Lifecycle(started: started, stopped: stopped)
        }

        override class func canInit(with _: URLRequest) -> Bool {
            true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            Self.signal(\.started)
        }

        override func stopLoading() {
            Self.signal(\.stopped)
        }

        private static func signal(
            _ keyPath: WritableKeyPath<State, AsyncStream<Void>.Continuation?>
        ) {
            let continuation = state.withLock { state in
                let continuation = state[keyPath: keyPath]
                state[keyPath: keyPath] = nil
                return continuation
            }
            continuation?.yield()
            continuation?.finish()
        }
    }
#endif
