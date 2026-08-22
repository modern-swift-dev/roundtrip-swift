import Foundation
import RoundTripREST

enum ExampleConfiguration {
    static let baseURL = URL(string: "https://example.com")
}

struct ExampleBaseURLProvider: BaseURLProvider {
    let baseURL: URL? = ExampleConfiguration.baseURL
}

struct ExampleAPIKeyProvider: ApiKeyProvider {
    var apiKey: String? {
        get async {
            nil
        }
    }
}
