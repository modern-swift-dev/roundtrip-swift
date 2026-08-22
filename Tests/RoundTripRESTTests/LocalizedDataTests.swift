import Foundation
@testable import RoundTripREST
import Testing

@Suite(.serialized) struct LocalizedDataTests {
    @Test func initializationAndSubscript() {
        var data: LocalizedData<String> = [.init("en"): "Hello", .init("fr"): "Bonjour"]
        #expect(!data.isEmpty)
        #expect(data.values.count == 2)
        #expect(data[.init("en")] == "Hello")
        data[.init("en")] = "Hi"
        data[.init("fr")] = nil
        #expect(data[.init("en")] == "Hi")
        #expect(data[.init("fr")] == nil)
    }

    @Test func dictionaryInitializationAndSupportedLanguages() {
        let data = LocalizedData([.init("en"): "Hello", .init("de"): "Hallo"])
        #expect(data[.init("en")] == "Hello")
        #expect(data.supportedLanguages.contains(.init("de")))
    }

    @Test func encodesAndDecodes() throws {
        let json = #"{"en":"Hello","fr":"Bonjour"}"#
        let encoded = try #require(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(LocalizedData<String>.self, from: encoded)
        #expect(decoded[.init("en")] == "Hello")
        #expect(decoded[.init("fr")] == "Bonjour")
        let roundTripped = try JSONDecoder().decode(LocalizedData<String>.self, from: JSONEncoder().encode(decoded))
        #expect(roundTripped == decoded)
    }

    @Test func supportsOtherValueTypes() throws {
        var data = LocalizedData<[String]>()
        data[.init("en")] = ["one", "two"]
        data[.init("fr")] = ["un", "deux"]
        let decoded = try JSONDecoder().decode(LocalizedData<[String]>.self, from: JSONEncoder().encode(data))
        #expect(decoded[.init("en")] == ["one", "two"])
    }
}
