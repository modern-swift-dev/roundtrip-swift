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

        @Suite(.serialized) struct URLRequestAdapterTests {

            // MARK: - Test Adapter

            struct TestAdapter: URLRequestAdapter {
                func adapt(_ request: URLRequest) -> URLRequest {
                    var request = request
                    request.setValue("Bearer token123", forHTTPHeaderField: "Authorization")
                    return request
                }
            }

            private func createMockedConfiguration() -> URLSessionConfiguration {
                let configuration = URLSessionConfiguration.default
                configuration.protocolClasses = [MockingURLProtocol.self]
                return configuration
            }

            // MARK: - DataTaskPublisher Adapter Tests

            @Test func dataTaskPublisherAdaptWithAdapter() async throws {
                let url = try #require(URL(string: "https://api.example.com/data"))
                let responseData = try #require(#"{"success": true}"#.data(using: .utf8))

                let mock = Mock(url: url, contentType: .json, statusCode: 200, data: [.get: responseData])
                mock.register()

                let session = URLSession(configuration: createMockedConfiguration())
                let adapter = TestAdapter()

                let publisher = session.dataTaskPublisher(for: url)
                    .adapt(adapter)

                let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(data: Data, response: URLResponse), Error>) in
                    var cancellable: AnyCancellable?
                    cancellable = publisher.sink(
                        receiveCompletion: { completion in
                            if case let .failure(error) = completion {
                                continuation.resume(throwing: error)
                            }
                            cancellable?.cancel()
                        },
                        receiveValue: { output in
                            continuation.resume(returning: output)
                        }
                    )
                }

                #expect((result.response as? HTTPURLResponse)?.statusCode == 200)
            }

            @Test func dataTaskPublisherAdaptWithNilAdapter() async throws {
                let url = try #require(URL(string: "https://api.example.com/data-nil"))
                let responseData = try #require(#"{"success": true}"#.data(using: .utf8))

                let mock = Mock(url: url, contentType: .json, statusCode: 200, data: [.get: responseData])
                mock.register()

                let session = URLSession(configuration: createMockedConfiguration())

                let publisher = session.dataTaskPublisher(for: url)
                    .adapt(nil)

                let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(data: Data, response: URLResponse), Error>) in
                    var cancellable: AnyCancellable?
                    cancellable = publisher.sink(
                        receiveCompletion: { completion in
                            if case let .failure(error) = completion {
                                continuation.resume(throwing: error)
                            }
                            cancellable?.cancel()
                        },
                        receiveValue: { output in
                            continuation.resume(returning: output)
                        }
                    )
                }

                #expect((result.response as? HTTPURLResponse)?.statusCode == 200)
            }

            // MARK: - DownloadTaskPublisher Adapter Tests

            @Test func downloadTaskPublisherAdaptWithAdapter() async throws {
                let url = try #require(URL(string: "https://api.example.com/download-adapt"))
                let responseData = try #require("download content".data(using: .utf8))

                let mock = Mock(url: url, contentType: .json, statusCode: 200, data: [.get: responseData])
                mock.register()

                let session = URLSession(configuration: createMockedConfiguration())
                let adapter = TestAdapter()

                let tempDestination = FileManager.default.temporaryDirectory.appendingPathComponent("adapted-\(UUID()).txt")
                defer {
                    do {
                        try FileManager.default.removeItem(at: tempDestination)
                    } catch {
                        Issue.record("Failed to remove temporary file: \(error)")
                    }
                }

                let publisher = try session.downloadTaskPublisher(for: url, destination: tempDestination)
                    .adapt(adapter)

                let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(url: URL, response: URLResponse), Error>) in
                    var cancellable: AnyCancellable?
                    cancellable = publisher.sink(
                        receiveCompletion: { completion in
                            if case let .failure(error) = completion {
                                continuation.resume(throwing: error)
                            }
                            cancellable?.cancel()
                        },
                        receiveValue: { output in
                            continuation.resume(returning: output)
                        }
                    )
                }

                #expect((result.response as? HTTPURLResponse)?.statusCode == 200)
            }

            @Test func downloadTaskPublisherAdaptWithNilAdapter() async throws {
                let url = try #require(URL(string: "https://api.example.com/download-nil"))
                let responseData = try #require("download content".data(using: .utf8))

                let mock = Mock(url: url, contentType: .json, statusCode: 200, data: [.get: responseData])
                mock.register()

                let session = URLSession(configuration: createMockedConfiguration())

                let tempDestination = FileManager.default.temporaryDirectory.appendingPathComponent("nil-adapted-\(UUID()).txt")
                defer {
                    do {
                        try FileManager.default.removeItem(at: tempDestination)
                    } catch {
                        Issue.record("Failed to remove temporary file: \(error)")
                    }
                }

                let publisher = try session.downloadTaskPublisher(for: url, destination: tempDestination)
                    .adapt(nil)

                let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(url: URL, response: URLResponse), Error>) in
                    var cancellable: AnyCancellable?
                    cancellable = publisher.sink(
                        receiveCompletion: { completion in
                            if case let .failure(error) = completion {
                                continuation.resume(throwing: error)
                            }
                            cancellable?.cancel()
                        },
                        receiveValue: { output in
                            continuation.resume(returning: output)
                        }
                    )
                }

                #expect((result.response as? HTTPURLResponse)?.statusCode == 200)
            }

            // MARK: - DataUploadTaskPublisher Adapter Tests

            @Test func dataUploadTaskPublisherAdaptWithAdapter() async throws {
                let url = try #require(URL(string: "https://api.example.com/upload-adapt"))
                let responseData = try #require(#"{"success": true}"#.data(using: .utf8))

                let mock = Mock(url: url, contentType: .json, statusCode: 200, data: [.post: responseData])
                mock.register()

                let session = URLSession(configuration: createMockedConfiguration())
                let adapter = TestAdapter()
                let uploadData = try #require("upload data".data(using: .utf8))

                let request = try #require(URLRequestBuilder(url: url)).setMethod(.post)
                let publisher = try session.dataUploadTaskPublisher(for: request, data: uploadData)
                    .adapt(adapter)

                let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(data: Data?, response: URLResponse), Error>) in
                    var cancellable: AnyCancellable?
                    cancellable = publisher.sink(
                        receiveCompletion: { completion in
                            if case let .failure(error) = completion {
                                continuation.resume(throwing: error)
                            }
                            cancellable?.cancel()
                        },
                        receiveValue: { output in
                            continuation.resume(returning: output)
                        }
                    )
                }

                #expect((result.response as? HTTPURLResponse)?.statusCode == 200)
            }

            @Test func dataUploadTaskPublisherAdaptWithNilAdapter() async throws {
                let url = try #require(URL(string: "https://api.example.com/upload-nil"))
                let responseData = try #require(#"{"success": true}"#.data(using: .utf8))

                let mock = Mock(url: url, contentType: .json, statusCode: 200, data: [.post: responseData])
                mock.register()

                let session = URLSession(configuration: createMockedConfiguration())
                let uploadData = try #require("upload data".data(using: .utf8))

                let request = try #require(URLRequestBuilder(url: url)).setMethod(.post)
                let publisher = try session.dataUploadTaskPublisher(for: request, data: uploadData)
                    .adapt(nil)

                let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(data: Data?, response: URLResponse), Error>) in
                    var cancellable: AnyCancellable?
                    cancellable = publisher.sink(
                        receiveCompletion: { completion in
                            if case let .failure(error) = completion {
                                continuation.resume(throwing: error)
                            }
                            cancellable?.cancel()
                        },
                        receiveValue: { output in
                            continuation.resume(returning: output)
                        }
                    )
                }

                #expect((result.response as? HTTPURLResponse)?.statusCode == 200)
            }

            // MARK: - FileUploadTaskPublisher Adapter Tests

            @Test func fileUploadTaskPublisherAdaptWithAdapter() async throws {
                let url = try #require(URL(string: "https://api.example.com/file-upload-adapt"))
                let responseData = try #require(#"{"success": true}"#.data(using: .utf8))

                let mock = Mock(url: url, contentType: .json, statusCode: 200, data: [.post: responseData])
                mock.register()

                let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("adapt-upload-\(UUID()).txt")
                try "test content".write(to: tempFile, atomically: true, encoding: .utf8)
                defer {
                    do {
                        try FileManager.default.removeItem(at: tempFile)
                    } catch {
                        Issue.record("Failed to remove temporary file: \(error)")
                    }
                }

                let session = URLSession(configuration: createMockedConfiguration())
                let adapter = TestAdapter()

                let request = try #require(URLRequestBuilder(url: url)).setMethod(.post)
                let publisher = try session.fileUploadTaskPublisher(for: request, file: tempFile)
                    .adapt(adapter)

                let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(data: Data?, response: URLResponse), Error>) in
                    var cancellable: AnyCancellable?
                    cancellable = publisher.sink(
                        receiveCompletion: { completion in
                            if case let .failure(error) = completion {
                                continuation.resume(throwing: error)
                            }
                            cancellable?.cancel()
                        },
                        receiveValue: { output in
                            continuation.resume(returning: output)
                        }
                    )
                }

                #expect((result.response as? HTTPURLResponse)?.statusCode == 200)
            }

            @Test func fileUploadTaskPublisherAdaptWithNilAdapter() async throws {
                let url = try #require(URL(string: "https://api.example.com/file-upload-nil"))
                let responseData = try #require(#"{"success": true}"#.data(using: .utf8))

                let mock = Mock(url: url, contentType: .json, statusCode: 200, data: [.post: responseData])
                mock.register()

                let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("nil-upload-\(UUID()).txt")
                try "test content".write(to: tempFile, atomically: true, encoding: .utf8)
                defer {
                    do {
                        try FileManager.default.removeItem(at: tempFile)
                    } catch {
                        Issue.record("Failed to remove temporary file: \(error)")
                    }
                }

                let session = URLSession(configuration: createMockedConfiguration())

                let request = try #require(URLRequestBuilder(url: url)).setMethod(.post)
                let publisher = try session.fileUploadTaskPublisher(for: request, file: tempFile)
                    .adapt(nil)

                let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(data: Data?, response: URLResponse), Error>) in
                    var cancellable: AnyCancellable?
                    cancellable = publisher.sink(
                        receiveCompletion: { completion in
                            if case let .failure(error) = completion {
                                continuation.resume(throwing: error)
                            }
                            cancellable?.cancel()
                        },
                        receiveValue: { output in
                            continuation.resume(returning: output)
                        }
                    )
                }

                #expect((result.response as? HTTPURLResponse)?.statusCode == 200)
            }
        }

    #endif
#endif
