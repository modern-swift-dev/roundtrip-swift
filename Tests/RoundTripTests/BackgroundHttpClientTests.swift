#if !os(Linux)
    import Foundation
    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
    @testable import RoundTrip
    import Testing

    @MainActor @Suite(.serialized) struct BackgroundHttpClientTests {

        @Test func initStoresInitialPublishedStateAndCompletionHandlerCanRun() {
            let client = BackgroundHttpClient(
                name: "BackgroundHttpClientTests.\(UUID().uuidString)",
                timeoutForRequest: 10,
                timeoutForResource: 20,
                httpShouldUsePipelining: true,
                allowsCellularAccess: false,
                httpShouldSetCookies: false,
                waitsForConnectivity: false,
                sessionSendsLaunchEvents: false,
                isDiscretionary: false,
                requestCachePolicy: .reloadIgnoringLocalCacheData,
                urlCache: URLCache(memoryCapacity: 0, diskCapacity: 0)
            )

            client.completionHandler = {}

            #expect(client.finishedTask == nil)
            #expect(client.completionHandler != nil)
        }

        @Test func uploadMissingFileThrowsBeforeStartingTransfer() throws {
            let client = BackgroundHttpClient(name: "BackgroundHttpClientTests.missing.\(UUID().uuidString)")
            let missingFile = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("txt")

            #expect(throws: ApiError.self) {
                try client.upload(
                    request: SimpleBackgroundRequest(url: try requestURL()),
                    file: missingFile
                )
            }
        }

        private func requestURL() throws -> URL {
            try #require(URL(string: "https://example.com/upload"))
        }
    }

    private struct SimpleBackgroundRequest: URLRequestConvertible {
        let url: URL

        func buildRequest(baseUrl _: URL?, encoder _: JSONEncoder) throws -> URLRequest {
            URLRequest(url: url)
        }
    }
#endif
