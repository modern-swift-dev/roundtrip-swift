#if canImport(Security)
    import Foundation

    /// Controls how ``NetworkService`` handles server-trust challenges.
    public enum ServerTrustPolicy: Sendable, Equatable {
        /// Uses the platform's standard certificate and hostname validation.
        case systemDefault

        /// Accepts any server certificate.
        ///
        /// Use this only for local development servers. It disables certificate
        /// and hostname validation for the session.
        case trustAllCertificates
    }
#endif
