#if !os(watchOS)
    #if canImport(Mocker)
        import Combine
        import Foundation
        #if canImport(FoundationNetworking)
            import FoundationNetworking
        #endif
        import Mocker
        import RoundTrip
        @testable import RoundTripREST
        import Testing

        @Suite(.serialized) struct NetworkServiceTests {
            private func configuration() -> URLSessionConfiguration {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.protocolClasses = [MockingURLProtocol.self]
                return configuration
            }

            @Test func executesGETAndPOSTRequests() async throws {
                let getURL = try #require(URL(string: "https://network-service.example.com/users"))
                let getData = Data(#"{"id":1}"#.utf8)
                Mock(url: getURL, contentType: .json, statusCode: 200, data: [.get: getData]).register()
                let service = NetworkService(configuration: configuration())
                let getResponse = try await service.execute(request: URLRequest(url: getURL))
                #expect(getResponse.statusCode == 200)
                #expect(getResponse.data == getData)

                let postURL = try #require(URL(string: "https://network-service.example.com/create"))
                Mock(url: postURL, contentType: .json, statusCode: 201, data: [.post: Data()]).register()
                var request = URLRequest(url: postURL)
                request.httpMethod = "POST"
                let postResponse = try await service.execute(request: request)
                #expect(postResponse.statusCode == 201)
            }

            @Test func downloadHandlesSuccessAndInvalidStatus() async throws {
                let url = try #require(URL(string: "https://network-service.example.com/file.txt"))
                Mock(url: url, contentType: .json, statusCode: 200, data: [.get: Data("hello".utf8)]).register()
                let service = NetworkService(configuration: configuration())
                let localURL = try await service.download(url: url, in: FileManager.default.temporaryDirectory, progress: nil)
                defer { try? FileManager.default.removeItem(at: localURL) }
                #expect(FileManager.default.fileExists(atPath: localURL.path))

                let missing = try #require(URL(string: "https://network-service.example.com/missing"))
                Mock(url: missing, contentType: .json, statusCode: 404, data: [.get: Data()]).register()
                await #expect(throws: ApiError.self) {
                    _ = try await service.download(url: missing, in: FileManager.default.temporaryDirectory, progress: nil)
                }
            }

            @Test func uploadWithProgressReturnsResponse() async throws {
                let url = try #require(URL(string: "https://network-service.example.com/upload"))
                Mock(url: url, contentType: .json, statusCode: 200, data: [.post: Data(#"{"success":true}"#.utf8)]).register()
                let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("roundtrip-upload-\(UUID()).txt")
                try Data("test".utf8).write(to: fileURL)
                defer { try? FileManager.default.removeItem(at: fileURL) }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                let response = try await NetworkService(configuration: configuration()).upload(
                    request: request, fileUrl: fileURL, timeout: 60, progress: Progress(totalUnitCount: 0)
                )
                #expect(response.data != nil || response.statusCode != 0)
            }

            @Test func exposesSessionPublisherAndCancellationOperations() {
                let service = NetworkService(configuration: configuration())
                let cancellable = service.httpHeaders.sink { _ in }
                #expect(service.session.configuration.protocolClasses?.contains { $0 == MockingURLProtocol.self } == true)
                service.cancelAll()
                service.invalidate()
                cancellable.cancel()
            }
        }
    #endif
#endif
