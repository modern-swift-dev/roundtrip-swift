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

        @Suite(.serialized) struct HttpClientTests {

            private var cancellables = Set<AnyCancellable>()

            // MARK: - Test Helpers

            private func usersURL() throws -> URL {
                try #require(URL(string: "https://api.example.com/users"))
            }

            private func errorURL() throws -> URL {
                try #require(URL(string: "https://api.example.com/error"))
            }

            private func itemsURL() throws -> URL {
                try #require(URL(string: "https://api.example.com/items"))
            }

            private func uploadURL() throws -> URL {
                try #require(URL(string: "https://httpclient.example.com/upload/async"))
            }

            private func uploadProgressURL() throws -> URL {
                try #require(URL(string: "https://httpclient.example.com/upload/progress"))
            }

            private func testURL() throws -> URL {
                try #require(URL(string: "https://api.example.com/test"))
            }

            private func testData(_ string: String) throws -> Data {
                try #require(string.data(using: .utf8))
            }

            private func createMockedConfiguration() -> URLSessionConfiguration {
                let configuration = URLSessionConfiguration.default
                configuration.protocolClasses = [MockingURLProtocol.self]
                return configuration
            }

            // MARK: - Execute Async Tests

            @Test func executeAsyncSuccess() async throws {
                let responseData = try testData(#"{"id": 1, "name": "John"}"#)

                let mock = Mock(url: try usersURL(), contentType: .json, statusCode: 200, data: [.get: responseData])
                mock.register()

                let client = HttpClient(configuration: createMockedConfiguration())
                let response = try await client.execute(request: try usersURL())

                #expect(response.statusCode == 200)
                #expect(response.data == responseData)
            }

            @Test func executeAsyncWith201() async throws {
                let responseData = try testData(#"{"id": 1}"#)

                let mock = Mock(url: try usersURL(), contentType: .json, statusCode: 201, data: [.post: responseData])
                mock.register()

                let request = try #require(URLRequestBuilder(url: try usersURL()))
                    .setMethod(.post)

                let client = HttpClient(configuration: createMockedConfiguration())
                let response = try await client.execute(request: request)

                #expect(response.statusCode == 201)
            }

            @Test func executeAsyncWithError() async throws {
                let mock = Mock(url: try errorURL(), contentType: .json, statusCode: 500, data: [.get: Data()])
                mock.register()

                let client = HttpClient(configuration: createMockedConfiguration())
                let response = try await client.execute(request: try errorURL())

                #expect(response.statusCode == 500)
                #expect(response.is50x == true)
            }

            // MARK: - Execute Publisher Tests

            @Test func executePublisherSuccess() async throws {
                let responseData = try testData(#"[{"id": 1}, {"id": 2}]"#)

                let mock = Mock(url: try itemsURL(), contentType: .json, statusCode: 200, data: [.get: responseData])
                mock.register()

                let client = HttpClient(configuration: createMockedConfiguration())

                let publisher = try client.execute(request: try itemsURL()) as AnyPublisher<ApiResponse, ApiError>
                let response = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ApiResponse, Error>) in
                    var cancellable: AnyCancellable?
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
                }

                #expect(response.statusCode == 200)
                #expect(response.data == responseData)
            }

            // MARK: - Upload Tests

            @Test func uploadAsyncSuccess() async throws {
                let uploadData = try testData("test data")
                let responseData = try testData(#"{"success": true}"#)

                let mock = Mock(url: try uploadURL(), contentType: .json, statusCode: 200, data: [.post: responseData])
                mock.register()
                let request = try #require(URLRequestBuilder(url: try uploadURL()))
                    .setMethod(.post)

                let client = HttpClient(configuration: createMockedConfiguration())
                let response = try await client.upload(request: request, data: uploadData)

                #expect(response.statusCode == 200)
            }

            @Test func uploadAsyncWithProgress() async throws {
                let uploadData = try testData("test data content")
                let responseData = try testData(#"{"success": true}"#)

                let mock = Mock(url: try uploadProgressURL(), contentType: .json, statusCode: 200, data: [.post: responseData])
                mock.register()
                let request = try #require(URLRequestBuilder(url: try uploadProgressURL()))
                    .setMethod(.post)

                let progress = Progress(totalUnitCount: 0)

                let client = HttpClient(configuration: createMockedConfiguration())
                let response = try await client.upload(request: request, data: uploadData, progress: progress)

                #expect(response.statusCode == 200)
                #expect(progress.totalUnitCount == Int64(uploadData.count))
            }

            // MARK: - File Upload Tests

            @Test func fileUploadSuccess() async throws {
                let responseData = try testData(#"{"success": true}"#)
                let uniqueUploadURL = try #require(URL(string: "https://api.example.com/upload/\(UUID().uuidString)"))

                let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test-upload-\(UUID()).txt")
                try "test content".write(to: tempFile, atomically: true, encoding: .utf8)
                defer {
                    do {
                        try FileManager.default.removeItem(at: tempFile)
                    } catch {
                        Issue.record("Failed to remove temporary file: \(error)")
                    }
                }
                let mock = Mock(url: uniqueUploadURL, contentType: .json, statusCode: 200, data: [.post: responseData])
                mock.register()
                let request = try #require(URLRequestBuilder(url: uniqueUploadURL))
                    .setMethod(.post)

                let client = HttpClient(configuration: createMockedConfiguration())
                let response = try await client.fileUpload(request: request, from: tempFile)

                #expect(response.statusCode == 200)
            }

            @Test func fileUploadWithProgress() async throws {
                let responseData = try testData(#"{"success": true}"#)
                let uniqueUploadURL = try #require(URL(string: "https://api.example.com/upload/\(UUID().uuidString)"))

                let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test-upload-progress-\(UUID()).txt")
                try "test content for progress".write(to: tempFile, atomically: true, encoding: .utf8)
                defer {
                    do {
                        try FileManager.default.removeItem(at: tempFile)
                    } catch {
                        Issue.record("Failed to remove temporary file: \(error)")
                    }
                }
                let mock = Mock(url: uniqueUploadURL, contentType: .json, statusCode: 200, data: [.post: responseData])
                mock.register()
                let request = try #require(URLRequestBuilder(url: uniqueUploadURL))
                    .setMethod(.post)

                let progress = Progress(totalUnitCount: 0)

                let client = HttpClient(configuration: createMockedConfiguration())
                let response = try await client.fileUpload(request: request, from: tempFile, progress: progress)

                #expect(response.statusCode == 200)
            }

            // MARK: - Invalidation Tests

            @Test func invalidateWithoutRecreate() {
                let client = HttpClient(configuration: createMockedConfiguration())
                client.invalidate(recreate: false)
                // Should not crash - session is invalidated
            }

            @Test func invalidateWithRecreate() async throws {
                let responseData = try testData(#"{"ok": true}"#)

                let mock = Mock(url: try testURL(), contentType: .json, statusCode: 200, data: [.get: responseData])
                mock.register()

                let client = HttpClient(configuration: createMockedConfiguration())
                client.invalidate(recreate: true)

                // Can still make requests after recreate
                let response = try await client.execute(request: try testURL())
                #expect(response.statusCode == 200)
            }
        }

    #endif
#endif
