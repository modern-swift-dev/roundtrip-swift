import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
#if canImport(UniformTypeIdentifiers)
    import UniformTypeIdentifiers
#endif

public extension URLRequestBuilder {

    /// A set of mime type. See https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types/Common_types
    enum MimeType: String, Sendable {
        /// Wildcard
        case any = "*/*"

        /// Any image
        case anyImage = "image/*"

        /// Any Audio
        case anyAudio = "audio/*"

        /// Any Audio
        case anyVideo = "video/*"

        /// Mp3
        case mp3 = "audio/mpeg"

        /// Mp4
        case mp4 = "audio/mp4"

        /// MP4 Video
        case m4v = "video/mp4"

        /// Form Encoded
        case formEncoded = "application/x-www-form-urlencoded"

        /// Binary
        case binary = "application/octet-stream"

        /// JSON
        case json = "application/json"

        /// XML
        case xml = "text/xml"

        /// CSS
        case css = "text/css"

        /// Javascript FIles
        case javascript = "application/javascript"

        /// PDF Images
        case pdf = "application/pdf"

        /// PNG Images
        case png = "image/png"

        /// SVG Images
        case svg = "image/svg+xml"

        /// PNG Images
        case jpeg = "image/jpeg"

        /// GIF Images
        case gif = "image/gif"

        /// Text
        case text = "text/plain"

        /// CSV Files
        case csv = "text/csv"

        /// HTML Files
        case html = "text/html"

        /// Zip Files
        case zip = "application/zip"

        /// Word Doc Format
        case doc = "application/msword"

        /// Word DocX Format
        case docx = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

        /// Excel Doc Format
        case xls = "application/vnd.ms-excel"

        /// Excel DocX Format
        case xlsx = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

        /// Powerpoint Doc Format
        case ppt = "application/vnd.ms-powerpoint"

        /// Powerpoint DocX Format
        case pptx = "application/vnd.openxmlformats-officedocument.presentationml.presentation"

        var debugDescription: String {
            rawValue
        }

        public static func mimeType(forExtension fileExtension: String) -> MimeType {
            extensionMap[fileExtension] ?? .binary
        }

        private static let extensionMap: [String: MimeType] = [
            "pdf": .pdf,
            "doc": .doc,
            "docx": .docx,
            "xls": .xls,
            "xlsx": .xlsx,
            "ppt": .ppt,
            "pptx": .pptx,
            "zip": .zip,
            "html": .html,
            "htm": .html,
            "txt": .text,
            "csv": .csv,
            "gif": .gif,
            "jpg": .jpeg,
            "jpeg": .jpeg,
            "png": .png,
            "svg": .svg,
            "js": .javascript,
            "jscript": .javascript,
            "css": .css,
            "mp3": .mp3,
            "mp4": .mp4,
            "m4v": .m4v,
            "json": .json,
            "xml": .xml
        ]

        #if canImport(UniformTypeIdentifiers)
            public var universalType: UTType? {
                .init(mimeType: rawValue)
            }
        #endif
    }
}
