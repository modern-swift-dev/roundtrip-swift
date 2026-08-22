#if !os(watchOS)
    #if canImport(Mocker)
        import Combine
        import Foundation
        #if canImport(FoundationNetworking)
            import FoundationNetworking
        #endif
        import Mocker
        import RoundTrip
        import Testing

        @Suite(.serialized) struct HttpClientDownloadTests {

            private func createMockedConfiguration() -> URLSessionConfiguration {
                let configuration = URLSessionConfiguration.default
                configuration.protocolClasses = [MockingURLProtocol.self]
                return configuration
            }

            // MARK: - Download Async Tests

            @Test func downloadAsyncSuccess() async throws {
                let url = try #require(URL(string: "https://api.example.com/files/document.txt"))
                let responseData = try #require("file content".data(using: .utf8))

                let mock = Mock(url: url, contentType: .json, statusCode: 200, data: [.get: responseData])
                mock.register()

                let tempDestination = FileManager.default.temporaryDirectory.appendingPathComponent("downloaded-\(UUID()).txt")
                defer {
                    do {
                        try FileManager.default.removeItem(at: tempDestination)
                    } catch {
                        Issue.record("Failed to remove temporary file: \(error)")
                    }
                }

                let client = HttpClient(configuration: createMockedConfiguration())
                let response = try await client.download(request: url, to: tempDestination)

                #expect(response.statusCode == 200)
            }

            @Test func downloadAsyncWithProgress() async throws {
                let url = try #require(URL(string: "https://api.example.com/files/large.bin"))
                let responseData = Data(repeating: 0, count: 1024)

                let mock = Mock(url: url, contentType: .json, statusCode: 200, data: [.get: responseData])
                mock.register()

                let tempDestination = FileManager.default.temporaryDirectory.appendingPathComponent("downloaded-progress-\(UUID()).bin")
                defer {
                    do {
                        try FileManager.default.removeItem(at: tempDestination)
                    } catch {
                        Issue.record("Failed to remove temporary file: \(error)")
                    }
                }

                let progress = Progress(totalUnitCount: 0)
                let client = HttpClient(configuration: createMockedConfiguration())
                let response = try await client.download(request: url, to: tempDestination, progress: progress)

                #expect(response.statusCode == 200)
            }

            // MARK: - Download Publisher Tests

            @Test func downloadPublisherSuccess() async throws {
                let url = try #require(URL(string: "https://api.example.com/files/doc.pdf"))
                let responseData = try #require("PDF content".data(using: .utf8))

                let mock = Mock(url: url, contentType: .json, statusCode: 200, data: [.get: responseData])
                mock.register()

                let tempDestination = FileManager.default.temporaryDirectory.appendingPathComponent("downloaded-pub-\(UUID()).pdf")
                defer {
                    do {
                        try FileManager.default.removeItem(at: tempDestination)
                    } catch {
                        Issue.record("Failed to remove temporary file: \(error)")
                    }
                }

                let client = HttpClient(configuration: createMockedConfiguration())

                let response = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ApiResponse, Error>) in
                    var cancellable: AnyCancellable?
                    do {
                        let publisher: AnyPublisher<ApiResponse, ApiError> = try client.download(
                            request: url,
                            destination: tempDestination
                        )
                        cancellable = publisher.sink(
                            receiveCompletion: { completion in
                                if case let .failure(error) = completion {
                                    continuation.resume(throwing: error)
                                }
                                cancellable?.cancel()
                            },
                            receiveValue: { response in
                                continuation.resume(returning: response)
                            }
                        )
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }

                #expect(response.statusCode == 200)
            }

            // MARK: - Multipart Upload Tests

            @Test func multipartUploadSuccess() async throws {
                let url = try #require(URL(string: "https://api.example.com/upload/multipart"))
                let responseData = try #require(#"{"success": true}"#.data(using: .utf8))

                let mock = Mock(url: url, contentType: .json, statusCode: 200, data: [.post: responseData])
                mock.register()

                guard let builder = try MultipartBody.Builder() else {
                    Issue.record("Failed to create builder")
                    return
                }

                let testData = try #require("test data".data(using: .utf8))
                builder
                    .addPart(name: "field", part: .init(name: "field", text: "value"))
                    .addBinaryPart("file", mimeType: URLRequestBuilder.MimeType.binary.rawValue, data: testData)

                let body = try builder.build()
                defer { body.cleanup() }

                let request = try #require(URLRequestBuilder(url: url))
                    .setMethod(.post)

                let client = HttpClient(configuration: createMockedConfiguration())
                let response = try await client.multiPartUpload(request: request, body: body)

                #expect(response.statusCode == 200)
            }

            @Test func multipartUploadWithProgress() async throws {
                let url = try #require(URL(string: "https://api.example.com/upload/multipart-progress"))
                let responseData = try #require(#"{"success": true}"#.data(using: .utf8))

                let mock = Mock(url: url, contentType: .json, statusCode: 200, data: [.post: responseData])
                mock.register()

                guard let builder = try MultipartBody.Builder() else {
                    Issue.record("Failed to create builder")
                    return
                }

                builder.addPart(name: "text", part: .init(name: "text", text: "hello world"))

                let body = try builder.build()
                defer { body.cleanup() }

                let request = try #require(URLRequestBuilder(url: url))
                    .setMethod(.post)

                let progress = Progress(totalUnitCount: 0)

                let client = HttpClient(configuration: createMockedConfiguration())
                let response = try await client.multiPartUpload(request: request, body: body, progress: progress)

                #expect(response.statusCode == 200)
            }

            // MARK: - WebSocket Tests

            @MainActor @Test func webSocketClientCreation() throws {
                let client = HttpClient(configuration: createMockedConfiguration())

                let wsURL = try #require(URL(string: "wss://api.example.com/ws"))
                let request = try #require(URLRequestBuilder(url: wsURL))
                    .setScheme(.secureWebSocket)

                let wssClient = try client.webSocketClient(request: request)
                // Just ensure it doesn't throw and returns a valid client
                _ = wssClient
            }

            @MainActor @Test func webSocketClientWithKeepAlive() throws {
                let client = HttpClient(configuration: createMockedConfiguration())

                let wsURL = try #require(URL(string: "wss://api.example.com/ws"))
                let request = try #require(URLRequestBuilder(url: wsURL))
                    .setScheme(.secureWebSocket)

                let keepAlive = WSSClient.KeepAliveConfig(enabled: true, delay: 15.0)
                let wssClient = try client.webSocketClient(request: request, keepAlive: keepAlive)
                // Just ensure it doesn't throw and returns a valid client
                _ = wssClient
            }
        }

    #endif
#endif
