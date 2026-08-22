import Foundation
@testable import RoundTripREST
import Testing

@Suite(.serialized) struct DistanceTests {
    @Test func initWithFloatLiteral() {
        let distance: Distance = 42.5; #expect(distance.value == 42.5)
    }

    @Test func initWithZeroFloatLiteral() {
        let distance: Distance = 0.0; #expect(distance.value == 0.0)
    }

    @Test func initWithNegativeFloatLiteral() {
        let distance: Distance = -10.5; #expect(distance.value == -10.5)
    }

    @Test func decodeFromDouble() throws {
        let data = try #require("42.5".data(using: .utf8))
        #expect(try JSONDecoder().decode(Distance.self, from: data).value == 42.5)
    }

    @Test func decodeFromString() throws {
        let data = try #require("\"42.5\"".data(using: .utf8))
        #expect(try JSONDecoder().decode(Distance.self, from: data).value == 42.5)
    }

    @Test func decodeFromInvalidString() throws {
        let data = try #require("\"not a number\"".data(using: .utf8))
        #expect(try JSONDecoder().decode(Distance.self, from: data).value == nil)
    }

    @Test func decodeFromNull() throws {
        let data = try #require("null".data(using: .utf8))
        #expect(try JSONDecoder().decode(Distance.self, from: data).value == nil)
    }

    @Test func encodeDistance() throws {
        let distance: Distance = 42.5
        let json = try #require(String(data: JSONEncoder().encode(distance), encoding: .utf8))
        #expect(json == "42.5")
    }

    @Test func encodeNilDistance() throws {
        let data = try #require("null".data(using: .utf8))
        let distance = try JSONDecoder().decode(Distance.self, from: data)
        let json = try #require(String(data: JSONEncoder().encode(distance), encoding: .utf8))
        #expect(json == "null")
    }

    @Test func equalDistances() {
        let one: Distance = 42.5; let two: Distance = 42.5; #expect(one == two)
    }

    @Test func unequalDistances() {
        let one: Distance = 42.5; let two: Distance = 50.0; #expect(one != two)
    }

    @Test func hashableDistance() {
        let one: Distance = 42.5; let two: Distance = 42.5; #expect(one.hashValue == two.hashValue)
    }

    @Test func distanceCanBeUsedInSet() {
        let one: Distance = 42.5
        let two: Distance = 50.0
        let three: Distance = 42.5
        #expect(Set([one, two, three]).count == 2)
    }
}
