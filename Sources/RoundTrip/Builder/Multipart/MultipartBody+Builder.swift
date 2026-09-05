import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
#if canImport(UIKit)
    import UIKit
#endif

public extension MultipartBody {

    struct Part: Sendable {
        public var name: String
        public var fileName: String?
        public var mimeType: String = "application/octet-stream"
        public var data: Data?
        public var fileURL: URL?

        public init(name: String, formData: [URLRequestBuilder.FormParameter]) {
            self.name = name
            mimeType = "application/x-www-form-urlencoded"
            data = formData.toBody()
        }

        public init(name: String, fileName: String? = nil, mimeType: String = URLRequestBuilder.MimeType.binary.rawValue, data: Data) {
            self.name = name
            self.fileName = fileName
            self.mimeType = mimeType
            self.data = data
        }

        public init(name: String, fileName: String? = nil, mimeType: String = URLRequestBuilder.MimeType.binary.rawValue, fileURL: URL) {
            self.name = name
            self.fileName = fileName ?? fileURL.lastPathComponent
            self.mimeType = mimeType
            self.fileURL = fileURL
        }

        public init(
            name: String,
            fileName: String? = nil,
            encodable: some Encodable,
            encoder: JSONEncoder = {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
                encoder.dateEncodingStrategy = .iso8601
                encoder.dataEncodingStrategy = .base64
                return encoder
            }()
        ) throws {
            self.name = name
            self.fileName = fileName
            mimeType = URLRequestBuilder.MimeType.json.rawValue
            data = try encoder.encode(encodable)
        }

        #if canImport(UIKit)
            public init(
                name: String,
                fileName: String? = nil,
                jpeg: UIImage,
                compression: CGFloat = 1.0
            ) {
                self.name = name
                self.fileName = fileName ?? "\(UUID().uuidString).jpeg"
                mimeType = URLRequestBuilder.MimeType.jpeg.rawValue
                data = jpeg.jpegData(compressionQuality: compression)
            }

            public init(
                name: String,
                fileName: String? = nil,
                png: UIImage
            ) {
                self.name = name
                self.fileName = fileName ?? "\(UUID().uuidString).png"
                mimeType = URLRequestBuilder.MimeType.png.rawValue
                data = png.pngData()
            }
        #endif

        public init(name: String, text: String) {
            self.name = name
            mimeType = URLRequestBuilder.MimeType.text.rawValue
            data = text.data(using: .utf8)
        }
    }

    /// A builder class to build a multipart body
    class Builder {

        private static let crlf = "\r\n"

        /// The Binary Stream
        private var data: OutputStream

        /// Boundary
        public let boundary: String

        /// The File URL
        public let url: URL

        /// Closed or not?
        private var closed: Bool = false

        private var writeError: (any Error)?

        /// The initializer
        /// - parameter boundary: The multipart boundary.
        /// - throws: This initializer currently does not throw an error.
        public convenience init?(_ boundary: String = UUID().uuidString) throws {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)").appendingPathExtension("mpbody")
            guard let data = OutputStream(url: url, append: false) else {
                return nil
            }
            self.init(boundary: boundary, url: url, outputStream: data)
        }

        init(boundary: String, url: URL, outputStream: OutputStream) {
            self.boundary = boundary
            self.url = url
            data = outputStream
            data.open()
        }

        deinit {
            if !closed {
                data.close()
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    RoundTripSupport.log(error)
                }
            }
        }

        /// Add a part
        /// - parameter name: The name of the body part
        /// - parameter part: The individual part
        /// - returns: self
        @discardableResult public func addPart(name: String, part: Part) -> MultipartBody.Builder {
            if let data = part.data, let fileName = part.fileName {
                addBinaryPart(name, fileName: fileName, mimeType: part.mimeType, data: data)
            } else if let data = part.data {
                addBinaryPart(name, mimeType: part.mimeType, data: data)
            }

            if let url = part.fileURL, let fileName = part.fileName {
                addBinaryPart(name, fileName: fileName, mimeType: part.mimeType, file: url)
            } else if let url = part.fileURL {
                addBinaryPart(name, fileName: url.lastPathComponent, mimeType: part.mimeType, file: url)
            }

            return self
        }

        /// Add a binary payload
        /// - parameter name: The name of the body part
        /// - parameter fileName: The filename
        /// - parameter mimeType: The mime type
        /// - parameter file: The File URL
        /// - returns: self
        @discardableResult public func addBinaryPart(
            _ name: String,
            fileName: String,
            mimeType: String = URLRequestBuilder.MimeType.binary.rawValue,
            file: URL
        ) -> MultipartBody.Builder {
            guard file.isFileURL, FileManager.default.fileExists(atPath: file.path) else {
                return self
            }
            let fileSize: Int
            do {
                guard let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
                    return self
                }
                fileSize = size
            } catch {
                RoundTripSupport.log(error)
                return self
            }
            guard let input = InputStream(url: file) else {
                return self
            }
            input.open()
            defer { input.close() }
            if let error = input.streamError {
                RoundTripSupport.log(error)
                return self
            }
            writeBodyPartHeader(name: name, fileName: fileName, mimeType: mimeType)
            // Keep file copying bounded even when the input cannot be memory mapped.
            withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 65536) { buffer in
                guard let baseAddress = buffer.baseAddress else {
                    return
                }
                // Snapshot the length before writing headers: the source can alias this output.
                var remainingBytes = fileSize
                while remainingBytes > 0, !closed, writeError == nil {
                    let count = input.read(baseAddress, maxLength: min(buffer.count, remainingBytes))
                    guard count > 0 else {
                        writeError = input.streamError ?? CocoaError(.fileReadUnknown)
                        return
                    }
                    write(UnsafeBufferPointer(start: baseAddress, count: count))
                    remainingBytes -= count
                }
            }
            return self
        }

        /// Add a binary payload
        /// - parameter name: The name of the body part
        /// - parameter fileName: The filename
        /// - parameter mimeType: The mime type
        /// - parameter data: The encodable
        /// - returns: self
        @discardableResult public func addBinaryPart(_ name: String, fileName: String, mimeType: String = URLRequestBuilder.MimeType.binary.rawValue, data: Data) -> MultipartBody.Builder {
            guard !name.isEmpty, !fileName.isEmpty else {
                return self
            }
            writeBodyPart(name: name, fileName: fileName, mimeType: mimeType, data: data)
            return self
        }

        /// Add a binary payload
        /// - parameter name: The name of the body part
        /// - parameter mimeType: The mime type
        /// - parameter data: The encodable
        /// - returns: self
        @discardableResult public func addBinaryPart(_ name: String, mimeType: String = URLRequestBuilder.MimeType.binary.rawValue, data: Data) -> MultipartBody.Builder {
            guard !name.isEmpty else {
                return self
            }
            writeBodyPart(name: name, fileName: nil, mimeType: mimeType, data: data)
            return self
        }

        #if canImport(UIKit)
            /// Add a binary payload
            /// - parameter name: The name of the body part
            /// - parameter fileName: The filename
            /// - parameter image: The image to upload
            /// - parameter compression: The compression. 0.0 being max, 1.0 being none
            /// - returns: self
            @discardableResult public func addJpgPart(_ name: String, fileName: String, image: UIImage, compression: CGFloat = 1.0) -> MultipartBody.Builder {
                guard !name.isEmpty, !fileName.isEmpty, let data = image.jpegData(compressionQuality: compression) else {
                    return self
                }
                writeBodyPart(name: name, fileName: fileName, mimeType: URLRequestBuilder.MimeType.jpeg.rawValue, data: data)
                return self
            }

            /// Add a binary payload
            /// - parameter name: The name of the body part
            /// - parameter fileName: The filename
            /// - parameter image: The image to upload
            /// - returns: self
            @discardableResult public func addPngPart(_ name: String, fileName: String, image: UIImage) -> MultipartBody.Builder {
                guard !name.isEmpty, !fileName.isEmpty, let data = image.pngData() else {
                    return self
                }
                writeBodyPart(name: name, fileName: fileName, mimeType: URLRequestBuilder.MimeType.png.rawValue, data: data)
                return self
            }
        #endif

        /// Add a JSON payload
        /// - parameter name: The name of the body part
        /// - parameter data: The encodable
        /// - parameter encoder: The JSON Encoder
        /// - returns: self
        @discardableResult public func addJsonPart(
            _ name: String,
            data: some Encodable,
            encoder: JSONEncoder = {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
                encoder.dateEncodingStrategy = .iso8601
                encoder.dataEncodingStrategy = .base64
                return encoder
            }()
        ) -> MultipartBody.Builder {
            guard !name.isEmpty else {
                return self
            }
            let encodedData: Data
            do {
                encodedData = try encoder.encode(data)
            } catch {
                RoundTripSupport.log(error)
                return self
            }
            writeBodyPart(name: name, fileName: nil, mimeType: URLRequestBuilder.MimeType.json.rawValue, data: encodedData)
            return self
        }

        /// Add a form-encoded payload
        /// - parameter name: The name of the body part
        /// - parameter data: The form parameters
        /// - returns: self
        @discardableResult public func addFormEncodedPart(_ name: String, data: [URLRequestBuilder.FormParameter]) -> MultipartBody.Builder {
            guard let data = data.toBody() else {
                return self
            }
            writeBodyPart(name: name, fileName: nil, mimeType: URLRequestBuilder.MimeType.formEncoded.rawValue, data: data)
            return self
        }

        /// Escape a string for use in Content-Disposition header values
        /// - parameter value: The string to escape
        /// - returns: The escaped string safe for HTTP headers
        private func escapeHeaderValue(_ value: String) -> String {
            value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: "\n", with: "")
        }

        /// Write a body part
        /// - parameter name: The name of the body part
        /// - parameter fileName: The filename of the file
        /// - parameter mimeType: The mimeType of the data
        /// - parameter data: The data to append
        private func writeBodyPart(name: String, fileName: String?, mimeType: String, data: Data) {
            writeBodyPartHeader(name: name, fileName: fileName, mimeType: mimeType)
            write(data)
        }

        private func writeBodyPartHeader(name: String, fileName: String?, mimeType: String) {
            let escapedName = escapeHeaderValue(name)
            write("\(Self.crlf)--\(boundary)\(Self.crlf)")
            if let fileName {
                let escapedFileName = escapeHeaderValue(fileName)
                write("Content-Disposition: form-data; name=\"\(escapedName)\"; filename=\"\(escapedFileName)\"\(Self.crlf)")
            } else {
                write("Content-Disposition: form-data; name=\"\(escapedName)\";\(Self.crlf)")
            }
            write("Content-Type: \(mimeType)\(Self.crlf)\(Self.crlf)")
        }

        /// Write a Data
        /// - parameter value: The data to write
        private func write(_ value: Data) {
            value.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                write(bytes.bindMemory(to: UInt8.self))
            }
        }

        private func write(_ bytes: UnsafeBufferPointer<UInt8>) {
            guard !closed, writeError == nil, let baseAddress = bytes.baseAddress else {
                return
            }
            var offset = 0
            while offset < bytes.count {
                let written = data.write(baseAddress.advanced(by: offset), maxLength: min(65536, bytes.count - offset))
                guard written > 0 else {
                    writeError = data.streamError ?? CocoaError(.fileWriteUnknown)
                    return
                }
                offset += written
            }
        }

        /// Write a string
        /// - parameter value: The string to write
        private func write(_ value: String) {
            write(Data(value.utf8))
        }

        /// Finish the body
        /// - returns: The body's data, mapped to virtual memory
        public func build() throws -> MultipartBody {
            guard !closed else {
                throw CocoaError(.fileWriteUnknown)
            }
            write("\(Self.crlf)--\(boundary)--\(Self.crlf)")
            data.close()
            closed = true
            do {
                if let error = writeError ?? data.streamError {
                    throw error
                }
                let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize.map(UInt64.init)
                return MultipartBody(contentType: "multipart/form-data; boundary=\(boundary)", url: url, size: fileSize)
            } catch {
                if FileManager.default.fileExists(atPath: url.path) {
                    do {
                        try FileManager.default.removeItem(at: url)
                    } catch {
                        RoundTripSupport.log(error)
                    }
                }
                throw error
            }
        }
    }
}
