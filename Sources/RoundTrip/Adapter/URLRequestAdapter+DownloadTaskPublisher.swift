#if canImport(Combine)
    import Combine
    import Foundation

    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif

    public extension URLSession.DownloadTaskPublisher {

        /// Adapt the data-task with specified adapter
        /// - parameter: The adapter
        /// - returns: The adapted publisher
        func adapt(_ adapter: (any URLRequestAdapter)?) throws -> URLSession.DownloadTaskPublisher {
            if let adapter {
                let adapted = adapter.adapt(request)
                return .init(request: adapted, destination: destination, session: session, progress: progress, pendingUnitCount: pendingUnitCount)
            }
            return self
        }
    }

#endif
