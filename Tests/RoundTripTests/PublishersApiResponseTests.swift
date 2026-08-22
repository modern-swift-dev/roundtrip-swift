#if canImport(Mocker)
    import Combine
    import Foundation
    import Mocker
    import RoundTrip
    import Testing

    @Suite(.serialized) struct PublishersApiResponseTests {

        // MARK: - validateStatus Tests

        @Test func validateStatusSuccess() async throws {
            let response = ApiResponse(status: 200, data: "test".data(using: .utf8))
            let publisher = Just(response)
                .setFailureType(to: ApiError.self)
                .eraseToAnyPublisher()
                .validateStatus(codes: [200, 201])

            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ApiResponse, Error>) in
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

            #expect(result.statusCode == 200)
        }

        @Test func validateStatusFailure() async throws {
            let response = ApiResponse(status: 404, data: nil)
            let publisher = Just(response)
                .setFailureType(to: ApiError.self)
                .eraseToAnyPublisher()
                .validateStatus(codes: [200, 201])

            do {
                _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ApiResponse, Error>) in
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
                Issue.record("Should have thrown")
            } catch let error as ApiError {
                if case let .invalidStatusCode(code, _) = error {
                    #expect(code == 404)
                } else {
                    Issue.record("Wrong error type")
                }
            }
        }

        // MARK: - tryDecode Tests

        struct TestModel: Codable, Equatable {
            let id: Int
            let name: String
        }

        @Test func tryDecodeSuccess() async throws {
            let model = TestModel(id: 1, name: "test")
            let jsonData = try JSONEncoder().encode(model)
            let response = ApiResponse(status: 200, data: jsonData)

            let publisher = Just(response)
                .setFailureType(to: ApiError.self)
                .eraseToAnyPublisher()
                .tryDecode(TestModel.self, decoder: JSONDecoder())

            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TestModel, Error>) in
                var cancellable: AnyCancellable?
                cancellable = publisher.sink(
                    receiveCompletion: { completion in
                        if case let .failure(error) = completion {
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                    }
                )
            }

            #expect(result == model)
        }

        @Test func tryDecodeFailsWithEmptyData() async {
            let response = ApiResponse(status: 200, data: nil)

            let publisher = Just(response)
                .setFailureType(to: ApiError.self)
                .eraseToAnyPublisher()
                .tryDecode(TestModel.self, decoder: JSONDecoder())

            do {
                _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TestModel, Error>) in
                    var cancellable: AnyCancellable?
                    cancellable = publisher.sink(
                        receiveCompletion: { completion in
                            if case let .failure(error) = completion {
                                continuation.resume(throwing: error)
                            }
                            cancellable?.cancel()
                        },
                        receiveValue: { value in
                            continuation.resume(returning: value)
                        }
                    )
                }
                Issue.record("Should have thrown")
            } catch let error as ApiError {
                if case .emptyResponseBody = error {
                    // Expected
                } else {
                    Issue.record("Expected emptyResponseBody, got \(error)")
                }
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }

        @Test func tryDecodeFailsWithInvalidJSON() async {
            let invalidData = "not json".data(using: .utf8)
            let response = ApiResponse(status: 200, data: invalidData)

            let publisher = Just(response)
                .setFailureType(to: ApiError.self)
                .eraseToAnyPublisher()
                .tryDecode(TestModel.self, decoder: JSONDecoder())

            do {
                _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TestModel, Error>) in
                    var cancellable: AnyCancellable?
                    cancellable = publisher.sink(
                        receiveCompletion: { completion in
                            if case let .failure(error) = completion {
                                continuation.resume(throwing: error)
                            }
                            cancellable?.cancel()
                        },
                        receiveValue: { value in
                            continuation.resume(returning: value)
                        }
                    )
                }
                Issue.record("Should have thrown")
            } catch let error as ApiError {
                if case .responseDecodingFailed = error {
                    // Expected
                } else {
                    Issue.record("Expected responseDecodingFailed, got \(error)")
                }
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }

        // MARK: - cleanup Tests

        @Test func cleanupCallsCleanupOnBody() async throws {
            guard let builder = try MultipartBody.Builder() else {
                Issue.record("Failed to create builder")
                return
            }

            builder.addPart(name: "field", part: .init(name: "field", text: "value"))

            let body = try builder.build()
            let fileURL = body.url

            #expect(FileManager.default.fileExists(atPath: fileURL.path))

            let response = ApiResponse(status: 200, data: nil)
            let publisher = Just(response)
                .setFailureType(to: ApiError.self)
                .eraseToAnyPublisher()
                .cleanup(body: body)

            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ApiResponse, Error>) in
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

            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

#endif
