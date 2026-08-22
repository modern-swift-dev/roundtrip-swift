#if canImport(Combine)
    import Combine
    import Foundation

    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif

    public extension URLSession.FileUploadTaskPublisher {

        /// Adapt the data-task with specified adapter
        /// - parameter: The adapter
        /// - returns: The adapted publisher
        func adapt(_ adapter: (any URLRequestAdapter)?) throws -> URLSession.FileUploadTaskPublisher {
            if let adapter {
                let adapted = adapter.adapt(request)
                return try session.fileUploadTaskPublisher(for: adapted, file: file, progress: progress)
            }
            return self
        }
    }

#endif
