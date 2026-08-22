import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public extension URLRequest {

    mutating func add(header value: String?, named name: String) {
        setValue(value, forHTTPHeaderField: name)
    }
}
