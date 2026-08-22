import Foundation
import RoundTrip
import Testing

@Suite(.serialized) struct PatchableValueTests {

    // MARK: - Value Extraction Tests

    @Test func valueWithModified() {
        let patchable = PatchableValue<String>.modified("test")
        #expect(patchable.value == "test")
    }

    @Test func valueWithUnmodified() {
        let patchable = PatchableValue<String>.unmodified
        #expect(patchable.value == nil)
    }

    @Test func valueWithDeleted() {
        let patchable = PatchableValue<String>.deleted
        #expect(patchable.value == nil)
    }

    // MARK: - isUnmodified Tests

    @Test func isUnmodifiedWithUnmodified() {
        let patchable = PatchableValue<String>.unmodified
        #expect(patchable.isUnmodified == true)
    }

    @Test func isUnmodifiedWithModified() {
        let patchable = PatchableValue<String>.modified("test")
        #expect(patchable.isUnmodified == false)
    }

    @Test func isUnmodifiedWithDeleted() {
        let patchable = PatchableValue<String>.deleted
        #expect(patchable.isUnmodified == false)
    }

    // MARK: - Update Factory Tests

    @Test func updateWithValue() {
        let patchable = PatchableValue<String>.update(value: "test")
        if case let .modified(value) = patchable {
            #expect(value == "test")
        } else {
            Issue.record("Expected modified case")
        }
    }

    @Test func updateWithNilValue() {
        let patchable = PatchableValue<String>.update(value: nil)
        if case .deleted = patchable {
            // success
        } else {
            Issue.record("Expected deleted case")
        }
    }

    // MARK: - Encoding Tests

    @Test func encodeUnmodified() throws {
        struct TestStruct: Codable {
            let name: PatchableValue<String>
        }

        let test = TestStruct(name: .unmodified)
        let encoder = JSONEncoder()
        let data = try encoder.encode(test)
        let json = try #require(String(data: data, encoding: .utf8))

        // Unmodified should produce empty object or object without the key
        #expect(json == "{}" || !json.contains("null"))
    }

    @Test func encodeModified() throws {
        struct TestStruct: Codable {
            let name: PatchableValue<String>
        }

        let test = TestStruct(name: .modified("John"))
        let encoder = JSONEncoder()
        let data = try encoder.encode(test)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("John"))
    }

    @Test func encodeDeleted() throws {
        struct TestStruct: Codable {
            let name: PatchableValue<String>
        }

        let test = TestStruct(name: .deleted)
        let encoder = JSONEncoder()
        let data = try encoder.encode(test)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("null"))
    }

    // MARK: - Decoding Tests

    @Test func decodeValueReturnsModified() throws {
        struct TestStruct: Codable {
            let name: PatchableValue<String>
        }

        let json = Data(#"{"name": "John"}"#.utf8)
        let decoder = JSONDecoder()
        let result = try decoder.decode(TestStruct.self, from: json)

        #expect(result.name.value == "John")
        #expect(result.name.isUnmodified == false)
    }

    @Test func decodeNullReturnsDeleted() throws {
        struct TestStruct: Codable {
            let name: PatchableValue<String>
        }

        let json = Data(#"{"name": null}"#.utf8)
        let decoder = JSONDecoder()
        let result = try decoder.decode(TestStruct.self, from: json)

        #expect(result.name.value == nil)
        #expect(result.name.isUnmodified == false)
        if case .deleted = result.name {
            // success
        } else {
            Issue.record("Expected deleted case")
        }
    }

    // MARK: - Complex Type Tests

    @Test func patchableWithIntType() {
        let patchable = PatchableValue<Int>.modified(42)
        #expect(patchable.value == 42)
    }

    @Test func patchableWithOptionalNestedType() {
        struct Nested: Codable, Equatable {
            let id: Int
            let name: String
        }

        let nested = Nested(id: 1, name: "Test")
        let patchable = PatchableValue<Nested>.modified(nested)
        #expect(patchable.value == nested)
    }

    @Test func encodeModifiedWithComplexType() throws {
        struct Nested: Codable, Equatable {
            let id: Int
        }

        struct TestStruct: Codable {
            let data: PatchableValue<Nested>
        }

        let test = TestStruct(data: .modified(Nested(id: 123)))
        let encoder = JSONEncoder()
        let data = try encoder.encode(test)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("123"))
    }
}
