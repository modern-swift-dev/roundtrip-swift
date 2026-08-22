#if canImport(Combine)
    import Combine
    import Foundation

    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif

    public extension URLSession.DataUploadTaskPublisher {

        /// Adapt the data-task with specified adapter
        /// - parameter: The adapter
        /// - returns: The adapted publisher
        func adapt(_ adapter: (any URLRequestAdapter)?) throws -> URLSession.DataUploadTaskPublisher {
            if let adapter {
                let adapted = adapter.adapt(request)
                return try session.dataUploadTaskPublisher(for: adapted, data: data, progress: progress)
            }
            return self
        }
    }

#endif
