import Foundation
#if canImport(Kronos) && !os(watchOS)
    private import Kronos
#endif
import os

enum RoundTripSupport {
    static func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        encoder.dataEncodingStrategy = .base64
        encoder.keyEncodingStrategy = .useDefaultKeys
        return encoder
    }

    static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .throw
        decoder.dateDecodingStrategy = .iso8601
        decoder.dataDecodingStrategy = .base64
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }

    static let posixCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .gmt
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let isoTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .gmt
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    static func log(_ error: any Error, message: String? = nil) {
        let logger = Logger(subsystem: "RoundTrip", category: "HTTP")
        let description = (error as? any LocalizedError)?.errorDescription ?? String(describing: error)
        if let message {
            logger.error("\(message, privacy: .public) --> \(description, privacy: .public)")
        } else {
            logger.error("\(description, privacy: .public)")
        }
    }

    static func logDebug(_ message: String) {
        Logger(subsystem: "RoundTrip", category: "HTTP").debug("\(message, privacy: .public)")
    }

    static func isCapturable(_ error: any Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
                case .notConnectedToInternet,
                     .cannotFindHost,
                     .cannotConnectToHost,
                     .timedOut,
                     .networkConnectionLost,
                     .dataNotAllowed,
                     .dnsLookupFailed,
                     .cannotLoadFromNetwork,
                     .callIsActive,
                     .internationalRoamingOff,
                     .httpTooManyRedirects,
                     .resourceUnavailable,
                     .appTransportSecurityRequiresSecureConnection,
                     .redirectToNonExistentLocation,
                     .cannotCloseFile,
                     .cannotCreateFile,
                     .cannotMoveFile,
                     .cannotOpenFile,
                     .cannotWriteToFile,
                     .noPermissionsToReadFile,
                     .unsupportedURL,
                     .badURL,
                     .fileDoesNotExist,
                     .fileIsDirectory,
                     .badServerResponse,
                     .dataLengthExceedsMaximum,
                     .cannotDecodeContentData,
                     .cannotDecodeRawData,
                     .cannotParseResponse,
                     .downloadDecodingFailedMidStream,
                     .downloadDecodingFailedToComplete,
                     .zeroByteResource,
                     .userAuthenticationRequired,
                     .userCancelledAuthentication,
                     .secureConnectionFailed,
                     .serverCertificateHasBadDate,
                     .serverCertificateUntrusted,
                     .serverCertificateHasUnknownRoot,
                     .serverCertificateNotYetValid,
                     .cancelled:
                    return false
                default:
                    return true
            }
        }

        if let cocoaError = error as? CocoaError {
            switch cocoaError.code {
                case .fileWriteOutOfSpace,
                     .coderReadCorrupt,
                     .coderInvalidValue,
                     .coderValueNotFound:
                    return true
                default:
                    return false
            }
        }

        if error is POSIXError {
            return false
        }

        return false
    }

    static func shortDuration(_ duration: TimeInterval) -> String {
        let formatter = MeasurementFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.unitStyle = .short
        formatter.unitOptions = .naturalScale
        return formatter.string(from: Measurement(value: duration, unit: UnitDuration.seconds))
    }

    static func byteCount(_ count: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.formattingContext = .standalone
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: count)
    }

    static func downloadDirectory() throws -> URL {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "app-cache"
        let directory = URL.cachesDirectory
            .appendingPathComponent("\(bundleIdentifier)-cache", isDirectory: true)
            .appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableDirectory = directory
        try mutableDirectory.setResourceValues(resourceValues)
        return mutableDirectory
    }

    static func fileSize(at url: URL) -> Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? NSNumber {
                return size.int64Value
            }
            return attributes[.size] as? Int64
        } catch {
            log(error)
            return nil
        }
    }
}

package extension Date {
    static var monotonic: Date {
        #if canImport(Kronos) && !os(watchOS)
            Clock.now ?? Date()
        #else
            Date()
        #endif
    }
}
