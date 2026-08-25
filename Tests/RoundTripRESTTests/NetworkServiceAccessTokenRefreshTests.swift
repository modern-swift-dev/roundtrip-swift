#if canImport(Combine)
    import Foundation
    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
    import RoundTrip
    @testable import RoundTripREST
    import Testing

    @Suite(.serialized) struct NetworkServiceAccessTokenRefreshTests {
        @Test func retriesBearerRequestOnceWithRefreshedToken() async throws {
            let requests = RefreshRequestRecorder(behavior: .acceptReplacementToken)
            let refresher = RefreshStubRefresher(replacementToken: "replacement-token", refreshURL: refreshURL)
            let service = makeService(requests: requests, refresher: refresher)

            let response = try await service.execute(request: request(token: "expired-token"))

            #expect(response.statusCode == 200)
            #expect(requests.paths == ["/resource", "/refresh", "/resource"])
            #expect(requests.authorizationHeaders == ["Bearer expired-token", nil, "Bearer replacement-token"])
            #expect(await refresher.failedTokens == ["expired-token"])
        }

        @Test func doesNotRefreshRequestWithoutBearerAuthentication() async throws {
            let requests = RefreshRequestRecorder(behavior: .alwaysUnauthorized)
            let refresher = RefreshStubRefresher(replacementToken: "replacement-token")
            let service = makeService(requests: requests, refresher: refresher)

            let response = try await service.execute(request: request(token: nil))

            #expect(response.statusCode == 401)
            #expect(requests.authorizationHeaders == [nil])
            #expect(await refresher.failedTokens.isEmpty)
        }

        @Test func limitsRequestToOneRetry() async throws {
            let requests = RefreshRequestRecorder(behavior: .alwaysUnauthorized)
            let refresher = RefreshStubRefresher(replacementToken: "replacement-token")
            let service = makeService(requests: requests, refresher: refresher)

            let response = try await service.execute(request: request(token: "expired-token"))

            #expect(response.statusCode == 401)
            #expect(requests.authorizationHeaders == ["Bearer expired-token", "Bearer replacement-token"])
            #expect(await refresher.failedTokens == ["expired-token"])
        }

        @Test func coalescesConcurrentRefreshesForTheSameFailedToken() async throws {
            let requests = RefreshRequestRecorder(behavior: .acceptReplacementToken)
            let refresher = RefreshStubRefresher(
                replacementToken: "replacement-token",
                delay: .milliseconds(100)
            )
            let service = makeService(requests: requests, refresher: refresher)

            try await withThrowingTaskGroup(of: ApiResponse.self) { group in
                for _ in 0 ..< 5 {
                    group.addTask {
                        try await service.execute(request: request(token: "expired-token"))
                    }
                }
                for try await response in group {
                    #expect(response.statusCode == 200)
                }
            }

            #expect(await refresher.failedTokens == ["expired-token"])
        }

        @Test func cancellingCoalescedWaiterThrowsCancellation() async throws {
            let requests = RefreshRequestRecorder(behavior: .acceptReplacementToken)
            let refresher = RefreshStubRefresher(
                replacementToken: "replacement-token",
                delay: .milliseconds(200)
            )
            let service = makeService(requests: requests, refresher: refresher)
            let first = Task {
                try await service.execute(request: request(token: "expired-token"))
            }
            while await refresher.failedTokens.isEmpty {
                try await Task.sleep(for: .milliseconds(5))
            }
            let waiter = Task {
                try await service.execute(request: request(token: "expired-token"))
            }
            try await Task.sleep(for: .milliseconds(30))

            waiter.cancel()

            await #expect(throws: CancellationError.self) {
                _ = try await waiter.value
            }
            #expect(try await first.value.statusCode == 200)
            #expect(await refresher.failedTokens == ["expired-token"])
        }

        @Test func retriesFileUploadWithRefreshedToken() async throws {
            let requests = RefreshRequestRecorder(behavior: .acceptReplacementToken)
            let refresher = RefreshStubRefresher(replacementToken: "replacement-token")
            let service = makeService(requests: requests, refresher: refresher)
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("roundtrip-refresh-upload-\(UUID().uuidString)")
            try Data("upload".utf8).write(to: fileURL)
            defer { try? FileManager.default.removeItem(at: fileURL) }
            var uploadRequest = request(token: "expired-token")
            uploadRequest.httpMethod = "POST"

            let response = try await service.upload(
                request: uploadRequest,
                fileUrl: fileURL,
                timeout: 60,
                progress: nil
            )

            #expect(response.statusCode == 200)
            #expect(requests.authorizationHeaders == ["Bearer expired-token", "Bearer replacement-token"])
        }

        @Test func restoresMultipartBodyBeforeRetry() async throws {
            let requests = RefreshRequestRecorder(behavior: .acceptReplacementToken)
            let refresher = RefreshStubRefresher(replacementToken: "replacement-token")
            let service = makeService(requests: requests, refresher: refresher)
            let builder = try #require(try MultipartBody.Builder())
            builder.addPart(name: "message", part: .init(name: "message", text: "hello"))
            let body = try builder.build()
            var uploadRequest = request(token: "expired-token")
            uploadRequest.httpMethod = "POST"

            let response = try await service.multiPartUpload(
                request: uploadRequest,
                body: body,
                timeout: 60,
                progress: nil
            )

            #expect(response.statusCode == 200)
            #expect(requests.authorizationHeaders == ["Bearer expired-token", "Bearer replacement-token"])
        }

        @Test func nilRefresherPreservesStandardBehavior() async throws {
            let requests = RefreshRequestRecorder(behavior: .alwaysUnauthorized)
            let service = makeService(requests: requests, refresher: nil)

            let response = try await service.execute(request: request(token: "expired-token"))

            #expect(response.statusCode == 401)
            #expect(requests.authorizationHeaders == ["Bearer expired-token"])
        }

        @Test func exposesTrustPolicyInitializers() {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 42
            let defaultService = NetworkService(configuration: configuration)
            let localService = NetworkService(
                configuration: configuration,
                serverTrustPolicy: .trustAllCertificates
            )

            #expect(defaultService.session.configuration.timeoutIntervalForRequest == 42)
            #expect(localService.session.configuration.timeoutIntervalForRequest == 42)
            defaultService.invalidate()
            localService.invalidate()
        }

        private var refreshURL: URL {
            URL(string: "https://roundtrip.example.com/refresh")!
        }

        private func makeService(
            requests: RefreshRequestRecorder,
            refresher: (any AccessTokenRefresher)?
        ) -> NetworkService {
            RefreshURLProtocol.requests = requests
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [RefreshURLProtocol.self]
            return NetworkService(
                configuration: configuration,
                accessTokenRefresher: refresher
            )
        }

        private func request(token: String?) -> URLRequest {
            var request = URLRequest(url: URL(string: "https://roundtrip.example.com/resource")!)
            if let token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            return request
        }
    }

    private actor RefreshStubRefresher: AccessTokenRefresher {
        private(set) var failedTokens: [String] = []
        private let replacementToken: String?
        private let delay: Duration?
        private let refreshURL: URL?

        init(replacementToken: String?, delay: Duration? = nil, refreshURL: URL? = nil) {
            self.replacementToken = replacementToken
            self.delay = delay
            self.refreshURL = refreshURL
        }

        func refreshAccessToken(
            after failedAccessToken: String,
            execute: @escaping NetworkRequestExecutor
        ) async throws -> String? {
            failedTokens.append(failedAccessToken)
            if let delay {
                try await Task.sleep(for: delay)
            }
            if let refreshURL {
                _ = try await execute(URLRequest(url: refreshURL))
            }
            return replacementToken
        }
    }

    private final class RefreshRequestRecorder: @unchecked Sendable {
        enum Behavior: Sendable {
            case acceptReplacementToken
            case alwaysUnauthorized
        }

        private let lock = NSLock()
        private let behavior: Behavior
        private var storedAuthorizationHeaders: [String?] = []
        private var storedPaths: [String] = []

        var authorizationHeaders: [String?] {
            lock.withLock { storedAuthorizationHeaders }
        }

        var paths: [String] {
            lock.withLock { storedPaths }
        }

        init(behavior: Behavior) {
            self.behavior = behavior
        }

        func response(for request: URLRequest) -> (status: Int, data: Data) {
            lock.withLock {
                let authorization = request.value(forHTTPHeaderField: "Authorization")
                storedAuthorizationHeaders.append(authorization)
                storedPaths.append(request.url?.path ?? "")
                if request.url?.path == "/refresh" {
                    return (200, Data())
                }
                switch behavior {
                    case .acceptReplacementToken:
                        return (authorization == "Bearer replacement-token" ? 200 : 401, Data())
                    case .alwaysUnauthorized:
                        return (401, Data())
                }
            }
        }
    }

    private class RefreshURLProtocol: URLProtocol, @unchecked Sendable {
        nonisolated(unsafe) static var requests: RefreshRequestRecorder?

        override class func canInit(with _: URLRequest) -> Bool {
            true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            guard let requests = Self.requests,
                  let url = request.url else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }
            let result = requests.response(for: request)
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: result.status,
                httpVersion: "HTTP/1.1",
                headerFields: [:]
            ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: result.data)
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }
#endif
