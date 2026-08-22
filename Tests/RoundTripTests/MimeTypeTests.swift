#if canImport(UniformTypeIdentifiers)
    import Foundation
    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
    import RoundTrip
    import Testing
    import UniformTypeIdentifiers

    @Suite(.serialized) struct MimeTypeTests {

        @Test(arguments: [
            (URLRequestBuilder.MimeType.any, "*/*"),
            (.anyImage, "image/*"),
            (.anyAudio, "audio/*"),
            (.anyVideo, "video/*"),
            (.json, "application/json"),
            (.xml, "text/xml"),
            (.html, "text/html"),
            (.text, "text/plain"),
            (.css, "text/css"),
            (.csv, "text/csv"),
            (.pdf, "application/pdf"),
            (.png, "image/png"),
            (.jpeg, "image/jpeg"),
            (.gif, "image/gif"),
            (.svg, "image/svg+xml"),
            (.mp3, "audio/mpeg"),
            (.mp4, "audio/mp4"),
            (.m4v, "video/mp4"),
            (.zip, "application/zip"),
            (.binary, "application/octet-stream"),
            (.formEncoded, "application/x-www-form-urlencoded"),
            (.javascript, "application/javascript"),
            (.doc, "application/msword"),
            (.docx, "application/vnd.openxmlformats-officedocument.wordprocessingml.document"),
            (.xls, "application/vnd.ms-excel"),
            (.xlsx, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"),
            (.ppt, "application/vnd.ms-powerpoint"),
            (.pptx, "application/vnd.openxmlformats-officedocument.presentationml.presentation")
        ])
        func rawValue(mimeType: URLRequestBuilder.MimeType, expected: String) {
            #expect(mimeType.rawValue == expected)
        }

        @Test(arguments: [
            ("pdf", URLRequestBuilder.MimeType.pdf),
            ("doc", .doc),
            ("docx", .docx),
            ("xls", .xls),
            ("xlsx", .xlsx),
            ("ppt", .ppt),
            ("pptx", .pptx),
            ("zip", .zip),
            ("html", .html),
            ("htm", .html),
            ("txt", .text),
            ("csv", .csv),
            ("gif", .gif),
            ("jpg", .jpeg),
            ("jpeg", .jpeg),
            ("png", .png),
            ("svg", .svg),
            ("js", .javascript),
            ("jscript", .javascript),
            ("css", .css),
            ("mp3", .mp3),
            ("mp4", .mp4),
            ("m4v", .m4v),
            ("json", .json),
            ("xml", .xml),
            ("xyz123", .binary)
        ])
        func mimeType(forExtension fileExtension: String, expected: URLRequestBuilder.MimeType) {
            #expect(URLRequestBuilder.MimeType.mimeType(forExtension: fileExtension) == expected)
        }

        @Test(arguments: [
            (URLRequestBuilder.MimeType.json, UTType.json),
            (.png, UTType.png),
            (.pdf, UTType.pdf)
        ])
        func universalType(mimeType: URLRequestBuilder.MimeType, expected: UTType) {
            #expect(mimeType.universalType == expected)
        }
    }

#endif
