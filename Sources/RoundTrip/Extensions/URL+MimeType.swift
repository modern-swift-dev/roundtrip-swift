import Foundation

#if canImport(UniformTypeIdentifiers)
    import UniformTypeIdentifiers
#endif

public extension URL {
    /// Return the prefered mime-type for the URL.
    ///
    /// - returns: The mime-type, can be nil!
    var preferedMimeType: String {
        #if canImport(UniformTypeIdentifiers)
            if #available(iOS 14, *),
               let type = UTType(filenameExtension: pathExtension, conformingTo: .content),
               let mimeType = type.preferredMIMEType {
                return mimeType
            }
        #endif

        // Fallback for iOS 13.
        switch pathExtension.lowercased() {
            // PDF
            case "pdf":
                return "application/pdf"
            // Images
            case "bmp":
                return "image/bmp"
            case "png":
                return "image/png"
            case "gif":
                return "image/gif"
            case "heif",
                 "heic":
                return "image/heic"
            case "jpeg",
                 "jpg":
                return "image/jpeg"
            case "svg":
                return "image/svg+xml"
            // video
            case "mpg",
                 "mpeg":
                return "video/mpeg"
            case "m4v":
                return "video/x-m4v"
            case "mp4",
                 "mpg4",
                 "mp4v":
                return "video/mp4"
            case "mov",
                 "qt":
                return "video/quicktime"
            case "webm":
                return "video/webm"
            // Microsoft documents
            case "ppt":
                return "application/vnd.ms-powerpoint"
            case "pptx",
                 "pptm":
                return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
            case "xls":
                return "application/vnd.ms-excel"
            case "xlsx",
                 "xlsb",
                 "xlsm":
                return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            case "doc":
                return "application/vnd.ms-word"
            case "docx":
                return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            // Text
            case "rtf":
                return "application/rtf"
            case "txt":
                return "text/plain"
            case "csv":
                return "text/csv"
            case "tsv":
                return "text/tab-separated-values"
            case "md":
                return "text/markdown"
            case "html":
                return "text/html"
            // 3d models
            case "usdz":
                return "model/vnd.usd+zip"
            // Others
            case "zip":
                return "application/zip"
            case "gz",
                 "tgz":
                return "application/gzip"
            case "json":
                return "application/json"
            case "xml":
                return "application/xml"
            default:
                return "application/octet-stream"
        }

    }
}
