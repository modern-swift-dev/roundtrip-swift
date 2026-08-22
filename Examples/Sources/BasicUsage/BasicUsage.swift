import Combine
import Foundation
import RoundTrip
import RoundTripREST

@main
struct BasicUsage {
    static func main() async {
        do {
            let request = try makeRequest()
            print("Constructed \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")

            let restClient = makeRESTClient()
            let restRequest = try restClient.createRequest(request)
            print("REST client prepared \(restRequest.url?.absoluteString ?? "")")

            guard CommandLine.arguments.contains("--execute") else {
                print("Pass --execute to send the HTTP request.")
                return
            }

            let response = try await HttpClient().execute(request: request)
            print("Received HTTP \(response.statusCode)")
        } catch {
            print("Example failed: \(error)")
        }
    }

    private static func makeRequest() throws -> URLRequest {
        guard let baseURL = ExampleConfiguration.baseURL,
              let builder = URLRequestBuilder(baseURL: baseURL, path: "") else {
            throw URLError(.badURL)
        }

        guard let request = builder
            .setMethod(.get)
            .addHeader(.accept(.json))
            .addQueryParam(name: "source", value: "basic-usage")
            .build() else {
            throw URLError(.badURL)
        }
        return request
    }

    private static func makeRESTClient() -> RestClient {
        RestClient(
            baseURLProvider: ExampleBaseURLProvider(),
            apiKeyProvider: ExampleAPIKeyProvider(),
            service: NetworkService(),
            headerProvider: nil,
            errorSubject: PassthroughSubject<ApiError, Never>()
        )
    }
}
