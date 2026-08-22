import Foundation

public protocol MultipartBodyConvertible {
    func multiPartBody(encoder: JSONEncoder) throws -> MultipartBody
}

extension MultipartBody: MultipartBodyConvertible {
    public func multiPartBody(encoder _: JSONEncoder) throws -> MultipartBody {
        self
    }
}
