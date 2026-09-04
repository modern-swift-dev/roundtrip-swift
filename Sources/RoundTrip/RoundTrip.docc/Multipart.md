# Multipart uploads

[Documentation index](<doc:RoundTrip>)

``MultipartBody/Builder`` writes the multipart body to a temporary file. Build it, upload it with `multiPartUpload`, and let the client clean it up after the transfer.

```swift
let builder = try MultipartBody.Builder()!
builder
    .addJsonPart("metadata", data: ["title": "Receipt"])
    .addBinaryPart(
        "file",
        fileName: "receipt.pdf",
        mimeType: "application/pdf",
        file: fileURL
    )

let body = try builder.build()
let request = URLRequestBuilder(string: "https://example.com/uploads")!
    .setMethod(.post)
let response = try await HttpClient().multiPartUpload(request: request, body: body)
try response.checkForStatusCodeValidity(validStatusCode: [201])
```

Do not call `cleanup()` before the upload finishes. Call it yourself only when you build a body but do not give it to a client.

The builder handles partial stream writes and reports write failures from `build()`. A failed build removes the incomplete temporary file instead of returning a truncated body.
