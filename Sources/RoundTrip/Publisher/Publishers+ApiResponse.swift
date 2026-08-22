#if canImport(Combine)
    import Combine
    import Foundation
    import os

    public extension Publisher where Output == ApiResponse, Failure == ApiError {

        /// Handle 401 errors automatically, returning an `ApiError.authenticationRequired` when 403 status code is detected
        ///
        /// - returns: The publisher
        func validateStatus(codes: [Int] = [200]) -> AnyPublisher<ApiResponse, ApiError> {
            flatMap { response -> AnyPublisher<ApiResponse, ApiError> in
                if !codes.contains(response.statusCode) {
                    return ApiError.invalidStatusCode(response.statusCode).fail()
                }

                return Just(response).setFailureType(to: ApiError.self).eraseToAnyPublisher()
            }.eraseToAnyPublisher()
        }

        /// Attempt json decoding for specififed type, throwing a `ApiError.emptyResponseBody` is the body
        /// is nil or empty
        ///
        /// - returns: The publisher
        func tryDecode<T: Decodable>(
            _: T.Type,
            decoder: JSONDecoder = {
                let decoder = JSONDecoder()
                decoder.nonConformingFloatDecodingStrategy = .throw
                decoder.dateDecodingStrategy = .iso8601
                decoder.dataDecodingStrategy = .base64
                return decoder
            }()
        ) -> AnyPublisher<T, ApiError> {
            tryMap {
                guard let data = $0.data else {
                    throw ApiError.emptyResponseBody
                }
                return data
            }
            .mapError { error -> ApiError in
                if let error = error as? ApiError {
                    return error
                }

                RoundTripSupport.log(error)
                return ApiError.responseDecodingFailed(nil, error)
            }
            .decode(type: T.self, decoder: decoder)
            .mapError { error -> ApiError in
                if let error = error as? ApiError {
                    return error
                }

                RoundTripSupport.log(error)
                return ApiError.responseDecodingFailed(nil, error)
            }
            .eraseToAnyPublisher()
        }

        /// Cleanup the multipart body after the request is complete
        func cleanup(body: MultipartBody) -> AnyPublisher<ApiResponse, ApiError> {
            handleEvents(
                receiveSubscription: nil,
                receiveOutput: nil,
                receiveCompletion: { _ in
                    body.cleanup()
                },
                receiveCancel: {
                    body.cleanup()
                }
            ).eraseToAnyPublisher()
        }

    }

#endif
