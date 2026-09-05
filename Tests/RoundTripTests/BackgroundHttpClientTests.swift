#if !os(Linux)
    import Foundation
    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
    @testable import RoundTrip
    import Synchronization
    import Testing

    @MainActor @Suite(.serialized) struct BackgroundHttpClientTests {

        @Test func downloadCompletionIsExposedToObjectiveCDelegateDispatch() {
            #expect(BackgroundHttpClient.instancesRespond(
                to: #selector(URLSessionDownloadDelegate.urlSession(_:downloadTask:didFinishDownloadingTo:))
            ))
            #expect(BackgroundHttpClient.instancesRespond(
                to: #selector(URLSessionTaskDelegate.urlSession(_:task:didFinishCollecting:))
            ))
        }

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

        @Test func releasingBackgroundClientDoesNotLeaveDelegateCycle() {
            var client: BackgroundHttpClient? = BackgroundHttpClient(name: "BackgroundHttpClientTests.release.\(UUID())")
            let isReleased = { [weak client] in client == nil }
            client = nil
            #expect(isReleased())
        }

        @Test func independentDelegatePreservesCompletedDownload() throws {
            let completed = Mutex<BackgroundHttpClient.BackgroundTask?>(nil)
            let delegate = BackgroundSessionDelegate { task in completed.withLock { $0 = task } }
            let name = "BackgroundHttpClientTests.persistence.\(UUID())"
            let session = URLSession(configuration: .background(withIdentifier: name))
            defer { session.invalidateAndCancel() }
            let task = session.downloadTask(with: try requestURL())
            let source = FileManager.default.temporaryDirectory.appendingPathComponent("background-\(UUID()).txt")
            let payload = Data("completed download".utf8)
            try payload.write(to: source)
            defer { try? FileManager.default.removeItem(at: source) }

            delegate.urlSession(session, downloadTask: task, didFinishDownloadingTo: source)

            let result = try #require(completed.withLock { $0 })
            defer { try? FileManager.default.removeItem(at: result.file) }
            #expect(result.sessionId == name)
            #expect(result.requestURL == task.currentRequest?.url)
            #expect(try Data(contentsOf: result.file) == payload)
            #expect(!FileManager.default.fileExists(atPath: source.path))
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
