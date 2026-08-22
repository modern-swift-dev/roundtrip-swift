@testable import BasicUsage
import Testing

@Suite(.serialized)
struct BasicUsageTests {
    @Test
    func exampleConfigurationProvidesTheExampleBaseURL() {
        #expect(ExampleConfiguration.baseURL?.absoluteString == "https://example.com")
        #expect(ExampleBaseURLProvider().baseURL == ExampleConfiguration.baseURL)
    }

    @Test
    func exampleAPIKeyProviderHasNoConfiguredKey() async {
        #expect(await ExampleAPIKeyProvider().apiKey == nil)
    }
}
