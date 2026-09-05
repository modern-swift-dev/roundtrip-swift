import Foundation
@testable import RoundTrip
import Testing

struct MultipartBodyWriteTests {
    @Test func retriesPartialWritesWithoutLosingBytes() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("multipart-write-\(UUID()).mpbody")
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let stream = PartialOutputStream(maximumWrite: 3)
        let builder = MultipartBody.Builder(boundary: "Boundary", url: url, outputStream: stream)
        let payload = Data(repeating: 65, count: 70000)
        builder.addBinaryPart("file", fileName: "test.bin", data: payload)
        let body = try builder.build()
        defer { body.cleanup() }

        var expected = Data("\r\n--Boundary\r\nContent-Disposition: form-data; name=\"file\"; filename=\"test.bin\"\r\nContent-Type: application/octet-stream\r\n\r\n".utf8)
        expected.append(payload)
        expected.append(Data("\r\n--Boundary--\r\n".utf8))
        #expect(stream.written == expected)
    }

    @Test(arguments: [0, 65536, 150_000]) func copiesFilePartsAcrossBufferAndPartialWriteBoundaries(size: Int) throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("multipart-source-\(UUID()).bin")
        let payload = Data((0 ..< size).map { UInt8($0 % 251) })
        try payload.write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("multipart-copy-\(UUID()).mpbody")
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let stream = PartialOutputStream(maximumWrite: 997)
        let builder = MultipartBody.Builder(boundary: "Boundary", url: url, outputStream: stream)
        builder.addBinaryPart("file", fileName: "test.bin", file: source)
        let body = try builder.build()
        defer { body.cleanup() }

        var expected = Data("\r\n--Boundary\r\nContent-Disposition: form-data; name=\"file\"; filename=\"test.bin\"\r\nContent-Type: application/octet-stream\r\n\r\n".utf8)
        expected.append(payload)
        expected.append(Data("\r\n--Boundary--\r\n".utf8))
        #expect(stream.written == expected)
    }

    @Test(arguments: [false, true]) func boundsCopyWhenSourceAliasesOutput(hardLink: Bool) throws {
        let builder = try #require(try MultipartBody.Builder("Boundary"))
        builder.addBinaryPart("first", data: Data("original".utf8))
        let original = try Data(contentsOf: builder.url)
        let source = hardLink
            ? builder.url.appendingPathExtension("link")
            : builder.url
        if hardLink {
            try FileManager.default.linkItem(at: builder.url, to: source)
        }
        defer {
            if hardLink {
                try? FileManager.default.removeItem(at: source)
            }
        }
        builder.addBinaryPart("copy", fileName: "copy.bin", file: source)
        let body = try builder.build()
        defer { body.cleanup() }

        var expected = original
        expected.append(Data("\r\n--Boundary\r\nContent-Disposition: form-data; name=\"copy\"; filename=\"copy.bin\"\r\nContent-Type: application/octet-stream\r\n\r\n".utf8))
        expected.append(original)
        expected.append(Data("\r\n--Boundary--\r\n".utf8))
        #expect(try Data(contentsOf: body.url) == expected)
    }

    @Test(arguments: [false, true]) func skipsEncodingAfterClosingOrWriteFailure(failed: Bool) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("multipart-finished-\(UUID()).mpbody")
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let stream = PartialOutputStream(maximumWrite: 3, failureResult: failed ? -1 : nil)
        let builder = MultipartBody.Builder(boundary: "Boundary", url: url, outputStream: stream)
        builder.addBinaryPart("first", data: Data("payload".utf8))
        if !failed {
            let body = try builder.build()
            body.cleanup()
        }

        let payload = EncodingCounter()
        builder.addJsonPart("ignored", data: payload)
        #expect(payload.encodingCount == 0)
        if failed {
            #expect(throws: CocoaError.self) { _ = try builder.build() }
        }
    }

    @Test(arguments: [0, -1]) func rejectsFailedWritesAndRemovesPartialFile(result: Int) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("multipart-write-\(UUID()).mpbody")
        try Data("partial".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let stream = PartialOutputStream(maximumWrite: 3, failureResult: result)
        let builder = MultipartBody.Builder(boundary: "Boundary", url: url, outputStream: stream)
        builder.addBinaryPart("file", data: Data("payload".utf8))

        let expectedError = CocoaError(result == -1 ? .fileWriteOutOfSpace : .fileWriteUnknown)
        #expect(throws: expectedError) { _ = try builder.build() }
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
}

private final class PartialOutputStream: OutputStream {
    let maximumWrite: Int
    let failureResult: Int?
    private(set) var written = Data()

    init(maximumWrite: Int, failureResult: Int? = nil) {
        self.maximumWrite = maximumWrite
        self.failureResult = failureResult
        super.init(toMemory: ())
    }

    override func open() {}

    override func close() {}

    override var streamError: (any Error)? {
        failureResult == -1 && !written.isEmpty ? CocoaError(.fileWriteOutOfSpace) : nil
    }

    override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        if let failureResult, !written.isEmpty {
            return failureResult
        }
        let count = min(maximumWrite, len)
        written.append(buffer, count: count)
        return count
    }
}

private final class EncodingCounter: Encodable {
    var encodingCount = 0

    func encode(to encoder: any Encoder) throws {
        encodingCount += 1
        var container = encoder.singleValueContainer()
        try container.encode("payload")
    }
}
