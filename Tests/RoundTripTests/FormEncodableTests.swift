import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import RoundTrip
import Testing

@Suite(.serialized) struct FormEncodableTests {

    // MARK: - String Tests

    @Test func stringFormEncodable() {
        let value = "hello"
        #expect(value.formEncodableValue() == "hello")
    }

    @Test func emptyStringFormEncodable() {
        let value = ""
        #expect(value.formEncodableValue() == "")
    }

    // MARK: - Int Tests

    @Test func intFormEncodable() {
        let value = 42
        #expect(value.formEncodableValue() == "42")
    }

    @Test func negativeIntFormEncodable() {
        let value: Int = -42
        #expect(value.formEncodableValue() == "-42")
    }

    @Test func int8FormEncodable() {
        let value: Int8 = 127
        #expect(value.formEncodableValue() == "127")
    }

    @Test func int16FormEncodable() {
        let value: Int16 = 32767
        #expect(value.formEncodableValue() == "32767")
    }

    @Test func int32FormEncodable() {
        let value: Int32 = 2_147_483_647
        #expect(value.formEncodableValue() == "2147483647")
    }

    @Test func int64FormEncodable() {
        let value: Int64 = 9_223_372_036_854_775_807
        #expect(value.formEncodableValue() == "9223372036854775807")
    }

    // MARK: - UInt Tests

    @Test func uintFormEncodable() {
        let value: UInt = 42
        #expect(value.formEncodableValue() == "42")
    }

    @Test func uint8FormEncodable() {
        let value: UInt8 = 255
        #expect(value.formEncodableValue() == "255")
    }

    @Test func uint16FormEncodable() {
        let value: UInt16 = 65535
        #expect(value.formEncodableValue() == "65535")
    }

    @Test func uint32FormEncodable() {
        let value: UInt32 = 4_294_967_295
        #expect(value.formEncodableValue() == "4294967295")
    }

    @Test func uint64FormEncodable() {
        let value: UInt64 = 18_446_744_073_709_551_615
        #expect(value.formEncodableValue() == "18446744073709551615")
    }

    // MARK: - Float Tests

    @Test func floatFormEncodable() {
        let value: Float = 3.14
        let result = value.formEncodableValue()
        #expect(result.hasPrefix("3.14"))
    }

    @Test func floatNegativeFormEncodable() {
        let value: Float = -3.14
        let result = value.formEncodableValue()
        #expect(result.hasPrefix("-3.14"))
    }

    @Test func floatWholeNumberFormEncodable() {
        let value: Float = 42.0
        #expect(value.formEncodableValue() == "42")
    }

    // MARK: - Double Tests

    @Test func doubleFormEncodable() {
        let value = 3.14159265359
        let result = value.formEncodableValue()
        #expect(result.hasPrefix("3.14"))
    }

    @Test func doubleNegativeFormEncodable() {
        let value: Double = -3.14
        #expect(value.formEncodableValue() == "-3.14")
    }

    @Test func doubleWholeNumberFormEncodable() {
        let value = 42.0
        #expect(value.formEncodableValue() == "42")
    }

    // MARK: - Bool Tests

    @Test func boolTrueFormEncodable() {
        let value = true
        #expect(value.formEncodableValue() == "true")
    }

    @Test func boolFalseFormEncodable() {
        let value = false
        #expect(value.formEncodableValue() == "false")
    }

    // MARK: - Data Tests

    @Test func dataFormEncodable() throws {
        let data = try #require("hello".data(using: .utf8))
        let result = data.formEncodableValue()
        #expect(result == data.base64EncodedString())
    }

    @Test func emptyDataFormEncodable() {
        let data = Data()
        let result = data.formEncodableValue()
        #expect(result == "")
    }

    // MARK: - Date Tests

    @Test func dateFormEncodable() {
        let date = Date(timeIntervalSince1970: 0)
        let result = date.formEncodableValue()
        #expect(result.contains("1970-01-01"))
    }

    // MARK: - FormParameter Tests

    @Test func formParameterToItem() {
        let param = URLRequestBuilder.FormParameter(name: "key", value: "value")
        let item = param.toItem()
        #expect(item.name == "key")
        #expect(item.value == "value")
    }

    @Test func formParametersToItems() {
        let params: [URLRequestBuilder.FormParameter] = [
            .init(name: "key1", value: "value1"),
            .init(name: "key2", value: "value2")
        ]
        let items = params.toItems()
        #expect(items.count == 2)
        #expect(items[0].name == "key1")
        #expect(items[1].name == "key2")
    }

    @Test func formParametersToBody() throws {
        let params: [URLRequestBuilder.FormParameter] = [
            .init(name: "key1", value: "value1"),
            .init(name: "key2", value: "value2")
        ]
        let body = try #require(params.toBody())
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.contains("key1=value1"))
        #expect(bodyString.contains("key2=value2"))
    }

    @Test func formParametersPreservePlusSignsAndReservedCharacters() throws {
        let name = "email+label &=%"
        let value = "a+b@example.com &=% é"
        let params: [URLRequestBuilder.FormParameter] = [.init(name: name, value: value)]
        let body = try #require(params.toBody())
        let encoded = try #require(String(data: body, encoding: .utf8))
        #expect(!encoded.contains("+"))
        #expect(encoded.contains("%2B"))

        let fields = encoded.split(separator: "&")
        #expect(fields.count == 1)
        let pair = try #require(fields.first).split(separator: "=", omittingEmptySubsequences: false)
        #expect(pair.count == 2)
        let decoded = pair.map {
            String($0).replacingOccurrences(of: "+", with: " ").removingPercentEncoding
        }
        #expect(decoded == [name, value])
    }

    @Test func emptyFormParametersToBody() {
        let params: [URLRequestBuilder.FormParameter] = []
        let body = params.toBody()
        #expect(body == nil)
    }
}
