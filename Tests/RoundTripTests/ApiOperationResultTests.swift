import Foundation
import RoundTrip
import Testing

@Suite(.serialized) struct ApiOperationResultTests {

    struct TestValue: Equatable {
        let id: Int
        let name: String
    }

    // MARK: - Initialization Tests

    @Test func initWithResponseAndValue() {
        let response = ApiResponse(status: 200, data: nil)
        let value = TestValue(id: 1, name: "test")
        let result = ApiOperationResult(response: response, value: value)

        #expect(result.value == value)
        #expect(result.response?.statusCode == 200)
    }

    @Test func initWithValueOnly() {
        let value = TestValue(id: 2, name: "test2")
        let result = ApiOperationResult(value: value)

        #expect(result.value == value)
        #expect(result.response?.statusCode == 200)
    }

    @Test func initWithNilValue() {
        let result = ApiOperationResult<TestValue?>(value: nil)
        #expect(result.value == nil)
    }

    @Test func initWithResponseAndNilValue() {
        let response = ApiResponse(status: 204)
        let result = ApiOperationResult<TestValue?>(response: response, value: nil)

        #expect(result.value == nil)
        #expect(result.response?.statusCode == 204)
    }
}
