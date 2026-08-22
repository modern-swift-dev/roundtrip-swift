import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public extension URLSession {

    /// Return an `URLSessionDataTask` for this `URLRequestConvertible`
    func dataTask(
        for convertible: any URLRequestConvertible,
        encoder: JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            encoder.dateEncodingStrategy = .iso8601
            encoder.dataEncodingStrategy = .base64
            return encoder
        }()
    ) throws -> URLSessionDataTask {
        let request = try convertible.buildRequest(baseUrl: nil, encoder: encoder)
        return dataTask(with: request)
    }

}
