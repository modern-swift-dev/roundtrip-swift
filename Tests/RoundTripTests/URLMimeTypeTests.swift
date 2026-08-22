#if canImport(UniformTypeIdentifiers)
    import Foundation
    import RoundTrip
    import Testing
    import UniformTypeIdentifiers

    @Suite(.serialized) struct URLMimeTypeTests {

        // MARK: - preferedMimeType Tests

        @Test func preferedMimeTypeForPDF() {
            let url = URL(fileURLWithPath: "/tmp/test.pdf")
            let mimeType = url.preferedMimeType
            #expect(mimeType == "application/pdf")
        }

        @Test func preferedMimeTypeForPNG() {
            let url = URL(fileURLWithPath: "/tmp/test.png")
            let mimeType = url.preferedMimeType
            #expect(mimeType == "image/png")
        }

        @Test func preferedMimeTypeForJPEG() {
            let url = URL(fileURLWithPath: "/tmp/test.jpg")
            let mimeType = url.preferedMimeType
            #expect(mimeType == "image/jpeg")
        }

        @Test func preferedMimeTypeForJPG() {
            let url = URL(fileURLWithPath: "/tmp/test.jpeg")
            let mimeType = url.preferedMimeType
            #expect(mimeType == "image/jpeg")
        }

        @Test func preferedMimeTypeForGIF() {
            let url = URL(fileURLWithPath: "/tmp/test.gif")
            let mimeType = url.preferedMimeType
            #expect(mimeType == "image/gif")
        }

        @Test func preferedMimeTypeForSVG() {
            let url = URL(fileURLWithPath: "/tmp/test.svg")
            let mimeType = url.preferedMimeType
            #expect(mimeType == "image/svg+xml")
        }

        @Test func preferedMimeTypeForJSON() {
            let url = URL(fileURLWithPath: "/tmp/test.json")
            let mimeType = url.preferedMimeType
            #expect(mimeType == "application/json")
        }

        @Test func preferedMimeTypeForXML() {
            let url = URL(fileURLWithPath: "/tmp/test.xml")
            let mimeType = url.preferedMimeType
            #expect(mimeType == "text/xml" || mimeType == "application/xml")
        }

        @Test func preferedMimeTypeForHTML() {
            let url = URL(fileURLWithPath: "/tmp/test.html")
            let mimeType = url.preferedMimeType
            #expect(mimeType == "text/html")
        }

        @Test func preferedMimeTypeForHTM() {
            let url = URL(fileURLWithPath: "/tmp/test.htm")
            let mimeType = url.preferedMimeType
            #expect(mimeType == "text/html")
        }

        @Test func preferedMimeTypeForCSS() {
            let url = URL(fileURLWithPath: "/tmp/test.css")
            let mimeType = url.preferedMimeType
            #expect(mimeType == "text/css")
        }

        @Test func preferedMimeTypeForJS() {
            let url = URL(fileURLWithPath: "/tmp/test.js")
            let mimeType = url.preferedMimeType
            #expect(mimeType.contains("javascript"))
        }

        @Test func preferedMimeTypeForTXT() {
            let url = URL(fileURLWithPath: "/tmp/test.txt")
            let mimeType = url.preferedMimeType
            #expect(mimeType == "text/plain")
        }

        @Test func preferedMimeTypeForCSV() {
            let url = URL(fileURLWithPath: "/tmp/test.csv")
            let mimeType = url.preferedMimeType
            #expect(mimeType == "text/csv")
        }

        @Test func preferedMimeTypeForMP3() {
            let url = URL(fileURLWithPath: "/tmp/test.mp3")
            let mimeType = url.preferedMimeType
            #expect(mimeType == "audio/mpeg")
        }

        @Test func preferedMimeTypeForMP4() {
            let url = URL(fileURLWithPath: "/tmp/test.mp4")
            let mimeType = url.preferedMimeType
            #expect(mimeType.contains("mp4") || mimeType.contains("video"))
        }

        @Test func preferedMimeTypeForZIP() {
            let url = URL(fileURLWithPath: "/tmp/test.zip")
            let mimeType = url.preferedMimeType
            #expect(mimeType == "application/zip")
        }

        @Test func preferedMimeTypeForDOC() {
            let url = URL(fileURLWithPath: "/tmp/test.doc")
            let mimeType = url.preferedMimeType
            // Different systems may return different MIME types for .doc
            #expect(mimeType == "application/msword" || mimeType == "application/vnd.ms-word")
        }

        @Test func preferedMimeTypeForDOCX() {
            let url = URL(fileURLWithPath: "/tmp/test.docx")
            let mimeType = url.preferedMimeType
            #expect(mimeType.contains("openxmlformats") || mimeType.contains("word"))
        }

        @Test func preferedMimeTypeForXLS() {
            let url = URL(fileURLWithPath: "/tmp/test.xls")
            let mimeType = url.preferedMimeType
            #expect(mimeType.contains("excel") || mimeType.contains("ms-excel"))
        }

        @Test func preferedMimeTypeForXLSX() {
            let url = URL(fileURLWithPath: "/tmp/test.xlsx")
            let mimeType = url.preferedMimeType
            #expect(mimeType.contains("openxmlformats") || mimeType.contains("spreadsheet"))
        }

        @Test func preferedMimeTypeForPPT() {
            let url = URL(fileURLWithPath: "/tmp/test.ppt")
            let mimeType = url.preferedMimeType
            #expect(mimeType.contains("powerpoint") || mimeType.contains("presentation"))
        }

        @Test func preferedMimeTypeForPPTX() {
            let url = URL(fileURLWithPath: "/tmp/test.pptx")
            let mimeType = url.preferedMimeType
            #expect(mimeType.contains("openxmlformats") || mimeType.contains("presentation"))
        }

        @Test func preferedMimeTypeForUnknownExtension() {
            let url = URL(fileURLWithPath: "/tmp/test.xyz123")
            let mimeType = url.preferedMimeType
            // Should return default for unknown extension
            #expect(mimeType == "application/octet-stream")
        }

        @Test func preferedMimeTypeForNoExtension() {
            let url = URL(fileURLWithPath: "/tmp/testfile")
            let mimeType = url.preferedMimeType
            // Should return default for no extension
            #expect(mimeType == "application/octet-stream")
        }
    }

#endif
