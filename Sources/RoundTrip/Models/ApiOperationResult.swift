/// An API Operation result
public struct ApiOperationResult<ResponseType: Sendable>: Sendable {

    /// The payload
    public private(set) var value: ResponseType

    /// The response
    public private(set) var response: ApiResponse?

    /// The Initializer
    public init(response: ApiResponse?, value: ResponseType) {
        self.response = response
        self.value = value
    }

    /// The Initializer
    public init(value: ResponseType) {
        response = .init(status: 200, data: nil, mimeType: "application/json", headers: [:])
        self.value = value
    }
}
