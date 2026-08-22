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

        @Suite(.serialized) struct URLSessionPublisherTests {

            private func createMockedConfiguration() -> URLSessionConfiguration {
                let configuration = URLSessionConfiguration.default
                configuration.protocolClasses = [MockingURLProtocol.self]
                return configuration
            }

            // MARK: - FileUploadTaskPublisher Tests

            @Test func fileUploadTaskPublisherSuccess() async throws {
                let url = try #require(URL(string: "https://api.example.com/upload/file"))
                let responseData = try #require(#"{"success": true}"#.data(using: .utf8))

                let mock = Mock(url: url, contentType: .json, statusCode: 200, data: [.post: responseData])
                mock.register()

                let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("upload-test-\(UUID()).txt")
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

            @Test func fileUploadTaskPublisherWithProgress() async throws {
                let url = try #require(URL(string: "https://api.example.com/upload/file-progress"))
                let responseData = try #require(#"{"success": true}"#.data(using: .utf8))

                let mock = Mock(url: url, contentType: .json, statusCode: 200, data: [.post: responseData])
                mock.register()

                let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("upload-progress-\(UUID()).txt")
                try "test content for progress".write(to: tempFile, atomically: true, encoding: .utf8)
                defer {
                    do {
                        try FileManager.default.removeItem(at: tempFile)
                    } catch {
                        Issue.record("Failed to remove temporary file: \(error)")
                    }
                }

                let session = URLSession(configuration: createMockedConfiguration())
                let progress = Progress(totalUnitCount: 0)

                let request = try #require(URLRequestBuilder(url: url)).setMethod(.post)
                let publisher = try session.fileUploadTaskPublisher(for: request, file: tempFile, progress: progress)

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

            // MARK: - DataUploadTaskPublisher Tests

            @Test func dataUploadTaskPublisherSuccess() async throws {
                let url = try #require(URL(string: "https://api.example.com/upload/data"))
                let responseData = try #require(#"{"success": true}"#.data(using: .utf8))

                let mock = Mock(url: url, contentType: .json, statusCode: 200, data: [.post: responseData])
                mock.register()

                let session = URLSession(configuration: createMockedConfiguration())
                let uploadData = try #require("test upload data".data(using: .utf8))

                let request = try #require(URLRequestBuilder(url: url)).setMethod(.post)
                let publisher = try session.dataUploadTaskPublisher(for: request, data: uploadData)

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

            @Test func dataUploadTaskPublisherWithProgress() async throws {
                let url = try #require(URL(string: "https://api.example.com/upload/data-progress"))
                let responseData = try #require(#"{"success": true}"#.data(using: .utf8))

                let mock = Mock(url: url, contentType: .json, statusCode: 200, data: [.post: responseData])
                mock.register()

                let session = URLSession(configuration: createMockedConfiguration())
                let uploadData = try #require("test upload data with progress".data(using: .utf8))
                let progress = Progress(totalUnitCount: 0)

                let request = try #require(URLRequestBuilder(url: url)).setMethod(.post)
                let publisher = try session.dataUploadTaskPublisher(for: request, data: uploadData, progress: progress)

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

            // MARK: - Publisher Properties Tests

            @Test func fileUploadTaskPublisherProperties() throws {
                let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("props-test-\(UUID()).txt")
                try "test".write(to: tempFile, atomically: true, encoding: .utf8)
                defer {
                    do {
                        try FileManager.default.removeItem(at: tempFile)
                    } catch {
                        Issue.record("Failed to remove temporary file: \(error)")
                    }
                }

                let session = URLSession.shared
                let url = try #require(URL(string: "https://urlsessionpublisher.example.com/upload/file"))
                let request = URLRequest(url: url)

                let publisher = URLSession.FileUploadTaskPublisher(
                    request: request,
                    file: tempFile,
                    session: session,
                    progress: nil
                )

                #expect(publisher.request.url == url)
                #expect(publisher.file == tempFile)
                #expect(publisher.progress == nil)
            }

            @Test func dataUploadTaskPublisherProperties() throws {
                let session = URLSession.shared
                let url = try #require(URL(string: "https://urlsessionpublisher.example.com/upload/data"))
                let request = URLRequest(url: url)
                let data = try #require("test".data(using: .utf8))

                let publisher = URLSession.DataUploadTaskPublisher(
                    request: request,
                    data: data,
                    session: session,
                    progress: nil
                )

                #expect(publisher.request.url == url)
                #expect(publisher.data == data)
                #expect(publisher.progress == nil)
            }
        }

    #endif
#endif
