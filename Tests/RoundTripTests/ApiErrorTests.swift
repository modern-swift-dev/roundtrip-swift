#if canImport(Combine)
    import Combine
    import Foundation
    import RoundTrip
    import Testing

    @Suite(.serialized) struct ApiErrorTests {

        @Test(arguments: [
            URLError.Code.notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .timedOut,
            .networkConnectionLost, .dataNotAllowed, .dnsLookupFailed, .cannotLoadFromNetwork,
            .callIsActive, .internationalRoamingOff, .httpTooManyRedirects, .resourceUnavailable,
            .redirectToNonExistentLocation
        ])
        func urlErrorMapsToNetworkUnreachable(code: URLError.Code) {
            guard case .networkUnreachable = URLError(code).asApiError else {
                Issue.record("Expected networkUnreachable")
                return
            }
        }

        @Test(arguments: [
            URLError.Code.cannotCloseFile, .cannotCreateFile, .cannotMoveFile, .cannotOpenFile,
            .cannotWriteToFile, .noPermissionsToReadFile
        ])
        func urlErrorMapsToFileSystemError(code: URLError.Code) {
            guard case .fileSystemError = URLError(code).asApiError else {
                Issue.record("Expected fileSystemError")
                return
            }
        }

        @Test(arguments: [URLError.Code.unsupportedURL, .badURL, .fileDoesNotExist, .fileIsDirectory])
        func urlErrorMapsToRequestEncodingFailed(code: URLError.Code) {
            guard case .requestEncodingFailed = URLError(code).asApiError else {
                Issue.record("Expected requestEncodingFailed")
                return
            }
        }

        @Test(arguments: [
            URLError.Code.badServerResponse, .dataLengthExceedsMaximum, .cannotDecodeContentData,
            .cannotDecodeRawData, .cannotParseResponse, .downloadDecodingFailedMidStream,
            .downloadDecodingFailedToComplete, .zeroByteResource
        ])
        func urlErrorMapsToResponseDecodingFailed(code: URLError.Code) {
            guard case .responseDecodingFailed = URLError(code).asApiError else {
                Issue.record("Expected responseDecodingFailed")
                return
            }
        }

        @Test(arguments: [
            URLError.Code.userAuthenticationRequired, .userCancelledAuthentication, .secureConnectionFailed,
            .serverCertificateHasBadDate, .serverCertificateUntrusted,
            .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid,
            .appTransportSecurityRequiresSecureConnection
        ])
        func urlErrorMapsToInsecureConnection(code: URLError.Code) {
            guard case .insecureConnection = URLError(code).asApiError else {
                Issue.record("Expected insecureConnection")
                return
            }
        }

        @Test func urlErrorCancelled() {
            guard case .cancelled = URLError(.cancelled).asApiError else {
                Issue.record("Expected cancelled")
                return
            }
        }

        @Test func urlErrorUnknownCode() {
            guard case .unknown = URLError(.backgroundSessionWasDisconnected).asApiError else {
                Issue.record("Expected unknown")
                return
            }
        }

        // MARK: - Non-URLError Mapping

        @Test func nonURLErrorMapsToUnknown() {
            struct CustomError: Error {}
            let error = CustomError()
            let apiError = error.asApiError
            if case .unknown = apiError {
                // success
            } else {
                Issue.record("Expected unknown, got \(apiError)")
            }
        }

        @Test func apiErrorReturnsSelf() {
            let apiError = ApiError.networkUnreachable
            let result = apiError.asApiError
            if case .networkUnreachable = result {
                // success
            } else {
                Issue.record("Expected networkUnreachable, got \(result)")
            }
        }

        // MARK: - Combine Fail Tests

        @Test func failPublisher() {
            let apiError = ApiError.networkUnreachable
            let publisher: AnyPublisher<String, ApiError> = apiError.fail()

            var receivedError: ApiError?
            let cancellable = publisher.sink(
                receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        receivedError = error
                    }
                },
                receiveValue: { _ in }
            )

            _ = cancellable
            if case .networkUnreachable = receivedError {
                // success
            } else {
                Issue.record("Expected networkUnreachable error")
            }
        }

        @Test func isCapturableUnknownWithRegularError() {
            struct RegularError: Error {}
            let apiError = ApiError.unknown(RegularError())
            #expect(apiError.isCapturable == false)
        }

        @Test func isCapturableNetworkUnreachable() {
            let apiError = ApiError.networkUnreachable
            #expect(apiError.isCapturable == false)
        }

        @Test func isCapturableInvalidURL() {
            let apiError = ApiError.invalidURL
            #expect(apiError.isCapturable == true)
        }

        @Test func isCapturableInvalidStatusCode() {
            let apiError = ApiError.invalidStatusCode(404)
            #expect(apiError.isCapturable == true)
        }

        @Test func isCapturableRequestEncodingFailed() {
            let apiError = ApiError.requestEncodingFailed
            #expect(apiError.isCapturable == true)
        }

        @Test func isCapturableResponseDecodingFailed() {
            struct TestError: Error {}
            let apiError = ApiError.responseDecodingFailed(nil, TestError())
            #expect(apiError.isCapturable == true)
        }

        @Test func isCapturableEmptyResponseBody() {
            let apiError = ApiError.emptyResponseBody
            #expect(apiError.isCapturable == true)
        }

        @Test func isCapturableInsecureConnection() {
            let apiError = ApiError.insecureConnection
            #expect(apiError.isCapturable == false)
        }

        @Test func isCapturableFileSystemError() {
            let apiError = ApiError.fileSystemError
            #expect(apiError.isCapturable == true)
        }

        @Test func isCapturableCancelled() {
            let apiError = ApiError.cancelled
            #expect(apiError.isCapturable == false)
        }

        @Test func isCapturableFileSizeTooBig() {
            let apiError = ApiError.fileSizeTooBig(1024)
            #expect(apiError.isCapturable == true)
        }

        @Test func isCapturableUnsupportedFileType() {
            let apiError = ApiError.unsupportedFileType
            #expect(apiError.isCapturable == true)
        }
    }

#endif
