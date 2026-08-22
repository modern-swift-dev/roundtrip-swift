# Migrating from SLHttp

[Documentation index](<doc:RoundTrip>)

RoundTrip extracts the HTTP library previously shipped as `SLHttp` in SwiftLibs. Update imports and target dependencies first:

```swift
// Before
import SLHttp

// After
import RoundTrip
```

The primary HTTP types keep their names: `HttpClient`, `URLRequestBuilder`, `URLRequestConvertible`, `MultipartBody`, `ApiResponse`, and `ApiError`.

Add RoundTrip as a package dependency, replace `.product(name: "SLHttp", package: "SwiftLibs")` with `.product(name: "RoundTrip", package: "roundtrip-swift")`, and update tests to import `RoundTrip`. The extracted package supports Apple platforms only, so remove any Linux target that depended on `SLHttp` before adopting it.
