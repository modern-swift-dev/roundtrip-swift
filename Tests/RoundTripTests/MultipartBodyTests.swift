import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import RoundTrip
import Testing

@Suite(.serialized) struct MultipartBodyTests {

    // MARK: - Part Initialization Tests

    @Test func partInitWithFormData() {
        let params: [URLRequestBuilder.FormParameter] = [
            .init(name: "key", value: "value")
        ]
        let part = MultipartBody.Part(name: "field", formData: params)
        #expect(part.name == "field")
    }

    @Test func partInitWithFileNameAndData() throws {
        let data = try #require("test data".data(using: .utf8))
        let part = MultipartBody.Part(name: "file", fileName: "test.txt", mimeType: URLRequestBuilder.MimeType.text.rawValue, data: data)
        #expect(part.name == "file")
        #expect(part.fileName == "test.txt")
    }

    @Test func partInitWithFileURL() throws {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("multipart-test-\(UUID()).txt")
        try "test content".write(to: tempFile, atomically: true, encoding: .utf8)
        defer {
            do {
                try FileManager.default.removeItem(at: tempFile)
            } catch {
                Issue.record("Failed to remove temporary file: \(error)")
            }
        }

        let part = MultipartBody.Part(name: "file", fileName: "test.txt", mimeType: URLRequestBuilder.MimeType.text.rawValue, fileURL: tempFile)
        #expect(part.name == "file")
        #expect(part.fileName == "test.txt")
    }

    @Test func partInitWithEncodable() throws {
        struct TestData: Codable {
            let value: Int
        }

        let part = try MultipartBody.Part(name: "data", fileName: "test.json", encodable: TestData(value: 42), encoder: JSONEncoder())
        #expect(part.name == "data")
    }

    @Test func partInitWithText() {
        let part = MultipartBody.Part(name: "text", text: "hello world")
        #expect(part.name == "text")
    }

    @Test func partIsSendable() {
        func requireSendable(_: (some Sendable).Type) {}

        requireSendable(MultipartBody.Part.self)
    }

    // MARK: - Builder Tests

    @Test func builderCreatesBody() throws {
        guard let builder = try MultipartBody.Builder() else {
            Issue.record("Failed to create builder")
            return
        }

        builder.addPart(name: "field", part: MultipartBody.Part(name: "field", text: "value"))

        let body = try builder.build()
        _ = body.url // URL is non-optional
        body.cleanup()
    }

    @Test func builderAddsBinaryPartFromData() throws {
        let data = try #require("binary content".data(using: .utf8))

        guard let builder = try MultipartBody.Builder() else {
            Issue.record("Failed to create builder")
            return
        }

        builder.addBinaryPart("file", fileName: "test.bin", mimeType: URLRequestBuilder.MimeType.binary.rawValue, data: data)

        let body = try builder.build()
        #expect((body.size ?? 0) > 0)
        body.cleanup()
    }

    @Test func builderAddsBinaryPartFromFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let sourceFile = tempDir.appendingPathComponent("source-multipart-\(UUID()).txt")
        try "source content".write(to: sourceFile, atomically: true, encoding: .utf8)
        defer {
            do {
                try FileManager.default.removeItem(at: sourceFile)
            } catch {
                Issue.record("Failed to remove temporary file: \(error)")
            }
        }

        guard let builder = try MultipartBody.Builder() else {
            Issue.record("Failed to create builder")
            return
        }

        builder.addBinaryPart("file", fileName: "uploaded.txt", mimeType: URLRequestBuilder.MimeType.text.rawValue, file: sourceFile)

        let body = try builder.build()
        #expect((body.size ?? 0) > 0)
        body.cleanup()
    }

    @Test func builderAddsJsonPart() throws {
        struct TestPayload: Codable {
            let id: Int
            let name: String
        }

        let payload = TestPayload(id: 1, name: "test")

        guard let builder = try MultipartBody.Builder() else {
            Issue.record("Failed to create builder")
            return
        }

        builder.addJsonPart("payload", data: payload, encoder: JSONEncoder())

        let body = try builder.build()
        #expect((body.size ?? 0) > 0)
        body.cleanup()
    }

    @Test func builderAddsFormEncodedPart() throws {
        guard let builder = try MultipartBody.Builder() else {
            Issue.record("Failed to create builder")
            return
        }

        builder.addFormEncodedPart("form", data: [
            URLRequestBuilder.FormParameter(name: "key1", value: "value1"),
            URLRequestBuilder.FormParameter(name: "key2", value: "value2")
        ])

        let body = try builder.build()
        #expect((body.size ?? 0) > 0)
        body.cleanup()
    }

    @Test func builderWithMultipleParts() throws {
        guard let builder = try MultipartBody.Builder() else {
            Issue.record("Failed to create builder")
            return
        }

        let binaryData = try #require("data".data(using: .utf8))
        builder
            .addPart(name: "text", part: .init(name: "text", text: "hello"))
            .addBinaryPart("binary", mimeType: URLRequestBuilder.MimeType.binary.rawValue, data: binaryData)

        let body = try builder.build()
        #expect((body.size ?? 0) > 0)
        #expect(body.contentType.contains("multipart/form-data"))
        body.cleanup()
    }

    @Test func builderEscapesHeaderNamesAndFilenames() throws {
        let data = try #require("payload".data(using: .utf8))

        guard let builder = try MultipartBody.Builder("Boundary") else {
            Issue.record("Failed to create builder")
            return
        }

        builder.addBinaryPart("field\"\r\n\\name", fileName: "file\"\r\n\\name.txt", mimeType: URLRequestBuilder.MimeType.text.rawValue, data: data)

        let body = try builder.build()
        defer { body.cleanup() }

        let content = try String(contentsOf: body.url, encoding: .utf8)
        #expect(content.contains(#"name="field\"\\name""#))
        #expect(content.contains(#"filename="file\"\\name.txt""#))
        #expect(!content.contains("field\"\r\n"))
        #expect(!content.contains("file\"\r\n"))
    }

    @Test func builderBuildTwiceThrows() throws {
        guard let builder = try MultipartBody.Builder() else {
            Issue.record("Failed to create builder")
            return
        }

        builder.addPart(name: "field", part: .init(name: "field", text: "value"))

        let body = try builder.build()
        defer { body.cleanup() }

        #expect(throws: CocoaError.self) {
            _ = try builder.build()
        }
    }

    @Test func builderIgnoresEmptyBinaryNameAndFilename() throws {
        let data = try #require("payload".data(using: .utf8))

        guard let builder = try MultipartBody.Builder("Boundary") else {
            Issue.record("Failed to create builder")
            return
        }

        builder
            .addBinaryPart("", fileName: "file.txt", mimeType: URLRequestBuilder.MimeType.text.rawValue, data: data)
            .addBinaryPart("file", fileName: "", mimeType: URLRequestBuilder.MimeType.text.rawValue, data: data)
            .addBinaryPart("", mimeType: URLRequestBuilder.MimeType.text.rawValue, data: data)

        let body = try builder.build()
        defer { body.cleanup() }

        let content = try String(contentsOf: body.url, encoding: .utf8)
        #expect(!content.contains("payload"))
        #expect(!content.contains("Content-Disposition"))
    }

    @Test func builderIgnoresMissingFileURL() throws {
        let missingFile = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID()).txt")

        guard let builder = try MultipartBody.Builder("Boundary") else {
            Issue.record("Failed to create builder")
            return
        }

        builder.addBinaryPart("file", fileName: "missing.txt", mimeType: URLRequestBuilder.MimeType.text.rawValue, file: missingFile)

        let body = try builder.build()
        defer { body.cleanup() }

        let content = try String(contentsOf: body.url, encoding: .utf8)
        #expect(!content.contains("missing.txt"))
        #expect(!content.contains("Content-Disposition"))
    }

    @Test func addPartUsesFileURLDefaultFilename() throws {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("multipart-default-\(UUID()).txt")
        try "source content".write(to: tempFile, atomically: true, encoding: .utf8)
        defer {
            do {
                try FileManager.default.removeItem(at: tempFile)
            } catch {
                Issue.record("Failed to remove temporary file: \(error)")
            }
        }

        guard let builder = try MultipartBody.Builder("Boundary") else {
            Issue.record("Failed to create builder")
            return
        }

        builder.addPart(name: "file", part: .init(name: "file", fileURL: tempFile))

        let body = try builder.build()
        defer { body.cleanup() }

        let content = try String(contentsOf: body.url, encoding: .utf8)
        #expect(content.contains(#"filename="\#(tempFile.lastPathComponent)""#))
        #expect(content.contains("source content"))
    }

    // MARK: - MultipartBody Tests

    @Test func bodyApplyToURLRequest() throws {
        guard let builder = try MultipartBody.Builder() else {
            Issue.record("Failed to create builder")
            return
        }

        builder.addPart(name: "field", part: .init(name: "field", text: "value"))

        let body = try builder.build()
        defer { body.cleanup() }

        let url = try #require(URL(string: "https://example.com"))
        var request = URLRequest(url: url)
        request = body.apply(request)

        #expect(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
        #expect(request.value(forHTTPHeaderField: "Content-Length") != nil)
    }

    @Test func bodyApplyToBuilder() throws {
        guard let builder = try MultipartBody.Builder() else {
            Issue.record("Failed to create builder")
            return
        }

        builder.addPart(name: "field", part: .init(name: "field", text: "value"))

        let body = try builder.build()
        defer { body.cleanup() }

        let requestBuilder = URLRequestBuilder()
            .setHost("example.com")
            .setMethod(.post)

        body.apply(requestBuilder)

        let request = try #require(requestBuilder.build())
        #expect(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
    }

    @Test func bodyCleanup() throws {
        guard let builder = try MultipartBody.Builder() else {
            Issue.record("Failed to create builder")
            return
        }

        builder.addPart(name: "field", part: .init(name: "field", text: "value"))

        let body = try builder.build()
        let fileURL = body.url

        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        body.cleanup()

        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }
}
