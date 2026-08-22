#if canImport(Combine)
    import Combine
    import Foundation

    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif

    public extension URLSession.DataTaskPublisher {

        /// Adapt the data-task with specified adapter
        /// - parameter: The adapter
        /// - returns: The adapted publisher
        func adapt(_ adapter: (any URLRequestAdapter)?) -> URLSession.DataTaskPublisher {
            if let adapter {
                let adapted = adapter.adapt(request)
                return session.dataTaskPublisher(for: adapted)
            }
            return self
        }
    }

#endif
