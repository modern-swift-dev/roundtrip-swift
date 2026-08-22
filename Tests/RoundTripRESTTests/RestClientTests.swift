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

    private struct RESTBaseURLProvider: BaseURLProvider { let baseURL: URL? }
    private struct RESTApiKeyProvider: ApiKeyProvider { let apiKey: String? }
    private struct RESTHeaderProvider: DefaultHttpHeaderProvider {
        let headers: [String: String]
        func provideDefaultHeaders() -> [String: String] {
            headers
        }
    }

    private struct RESTRequest: URLRequestConvertible {
        let path: String
        let method: String
        init(path: String, method: String = "GET") {
            self.path = path; self.method = method
        }

        func buildRequest(baseUrl: URL?, encoder _: JSONEncoder) throws -> URLRequest {
            guard let baseUrl else {
                throw ApiError.invalidURL
            }
            var request = URLRequest(url: baseUrl.appendingPathComponent(path))
            request.httpMethod = method
            return request
        }
    }

    private struct RESTResponse: Codable, Equatable { let id: Int; let name: String }
    private struct RESTMultipartRequest: URLRequestConvertible, MultipartBodyConvertible {
        let body: MultipartBody?
        let error: (any Error)?
        func buildRequest(baseUrl: URL?, encoder _: JSONEncoder) throws -> URLRequest {
            guard let baseUrl else {
                throw ApiError.invalidURL
            }
            var request = URLRequest(url: baseUrl.appendingPathComponent("upload"))
            request.httpMethod = "POST"
            return request
        }

        func multiPartBody(encoder _: JSONEncoder) throws -> MultipartBody {
            if let error {
                throw error
            }
            guard let body else {
                throw ApiError.requestEncodingFailed
            }
            return body
        }
    }

    private final class RESTStubNetworkService: NetworkServiceProtocol, @unchecked Sendable {
        let httpHeaders = Empty<[AnyHashable: Any], Never>().eraseToAnyPublisher()
        let session = URLSession(configuration: .ephemeral)
        var executeResponse = ApiResponse(status: 200)
        var uploadResponse = ApiResponse(status: 201)
        var multipartResponse = ApiResponse(status: 201)
        private(set) var uploadedRequest: URLRequest?
        private(set) var multipartRequest: URLRequest?
        func execute(request _: URLRequest) async throws -> ApiResponse {
            executeResponse
        }

        func upload(request: URLRequest, fileUrl _: URL, timeout _: TimeInterval, progress _: Progress?) async throws -> ApiResponse {
            uploadedRequest = request; return uploadResponse
        }

        func multiPartUpload(
            request: URLRequest,
            body _: MultipartBody,
            timeout _: TimeInterval,
            progress _: Progress?
        ) async throws -> ApiResponse {
            multipartRequest = request; return multipartResponse
        }

        func download(url _: URL, in _: URL, progress _: Progress?) async throws -> URL {
            throw ApiError.invalidURL
        }

        func cancelAll() {}
        func invalidate() {}
    }

    @Suite(.serialized) struct RestClientTests {
        private func configuration() -> URLSessionConfiguration {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [MockingURLProtocol.self]
            return configuration
        }

        private func client(
            baseURL: URL? = URL(string: "https://rest-client.example.com"), apiKey: String? = "test-api-key",
            headers: [String: String] = [:], service: (any NetworkServiceProtocol)? = nil,
            errorSubject: PassthroughSubject<ApiError, Never> = .init()
        ) -> RestClient {
            RestClient(
                baseURLProvider: RESTBaseURLProvider(baseURL: baseURL), apiKeyProvider: RESTApiKeyProvider(apiKey: apiKey),
                service: service ?? NetworkService(configuration: configuration()),
                headerProvider: headers.isEmpty ? nil : RESTHeaderProvider(headers: headers), errorSubject: errorSubject
            )
        }

        @Test func createsRequestsAndAddsHeaders() throws {
            let request = try client(headers: ["X-Test": "value"]).createRequest(RESTRequest(path: "users"))
            #expect(request.url?.absoluteString == "https://rest-client.example.com/users")
            #expect(request.value(forHTTPHeaderField: "X-Test") == "value")
            #expect(throws: ApiError.self) { _ = try client(baseURL: nil).createRequest(RESTRequest(path: "users")) }
        }

        @Test func executesRawAndDecodableResponses() async throws {
            let url = try #require(URL(string: "https://rest-client.example.com/users"))
            let data = Data(#"{"id":1,"name":"John"}"#.utf8)
            Mock(url: url, contentType: .json, statusCode: 200, data: [.get: data]).register()
            let restClient = client()
            let raw = try await restClient.execute(request: RESTRequest(path: "users"))
            #expect(raw.statusCode == 200)
            let result: ApiOperationResult<RESTResponse> = try await restClient.execute(request: RESTRequest(path: "users"))
            #expect(result.value == RESTResponse(id: 1, name: "John"))
        }

        @Test func mapsInvalidStatusEmptyBodiesAndDecodeFailuresToAPIErrors() async throws {
            let url = try #require(URL(string: "https://rest-client.example.com/users"))
            let restClient = client()
            Mock(url: url, contentType: .json, statusCode: 404, data: [.get: Data()]).register()
            await #expect(throws: ApiError.self) { let _: ApiOperationResult<RESTResponse> = try await restClient.execute(request: RESTRequest(path: "users")) }
            Mock(url: url, contentType: .json, statusCode: 200, data: [.get: Data()]).register()
            await #expect(throws: ApiError.self) { let _: ApiOperationResult<RESTResponse> = try await restClient.execute(request: RESTRequest(path: "users")) }
            Mock(url: url, contentType: .json, statusCode: 200, data: [.get: Data(#"{"invalid":true}"#.utf8)]).register()
            await #expect(throws: ApiError.self) { let _: ApiOperationResult<RESTResponse> = try await restClient.execute(request: RESTRequest(path: "users")) }
        }

        @Test func exposesAndRequiresAPIKey() async throws {
            let restClient = client(apiKey: "key")
            let apiKey = await restClient.apiKey()
            #expect(apiKey == "key")
            let requiredKey = try await restClient.requireApiKey()
            #expect(requiredKey == "key")
            await #expect(throws: ApiError.self) { _ = try await client(apiKey: nil).requireApiKey() }
        }

        @Test func forwardsApiErrorsToSubject() async throws {
            let url = try #require(URL(string: "https://rest-client.example.com/users"))
            Mock(url: url, contentType: .json, statusCode: 500, data: [.get: Data()]).register()
            let subject = PassthroughSubject<ApiError, Never>()
            var received = false
            let cancellable = subject.sink { _ in received = true }
            defer { cancellable.cancel() }
            await #expect(throws: ApiError.self) { _ = try await client(errorSubject: subject).execute(request: RESTRequest(path: "users")) }
            #expect(received)
        }

        @Test func uploadsAndPostsMultipartBodiesWithStubService() async throws {
            let service = RESTStubNetworkService()
            service.uploadResponse = ApiResponse(status: 201, data: Data(#"{"id":7,"name":"Upload"}"#.utf8))
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("roundtrip-client-upload-\(UUID()).txt")
            try Data("test".utf8).write(to: fileURL)
            defer { try? FileManager.default.removeItem(at: fileURL) }
            let restClient = client(service: service)
            let upload: ApiOperationResult<RESTResponse> = try await restClient.upload(request: RESTRequest(path: "upload", method: "POST"), fileUrl: fileURL)
            #expect(upload.value == RESTResponse(id: 7, name: "Upload"))
            #expect(service.uploadedRequest?.httpMethod == "POST")

            let optionalBuilder = try MultipartBody.Builder()
            let builder = try #require(optionalBuilder)
            builder.addPart(name: "field", part: .init(name: "field", text: "value"))
            let body = try builder.build()
            defer { body.cleanup() }
            service.multipartResponse = ApiResponse(status: 201, data: Data(#"{"id":8,"name":"Multipart"}"#.utf8))
            let multipart: ApiOperationResult<RESTResponse> = try await restClient.postMultipart(request: RESTMultipartRequest(body: body, error: nil))
            #expect(multipart.value == RESTResponse(id: 8, name: "Multipart"))
            #expect(service.multipartRequest?.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
        }
    }
#endif
