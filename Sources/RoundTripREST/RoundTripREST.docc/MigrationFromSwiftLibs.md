# Migrating from SLREST

[Documentation index](<doc:RoundTripREST>)

RoundTripREST extracts the REST library previously shipped as `SLREST` in SwiftLibs. It depends on the separate `RoundTrip` HTTP product.

```swift
// Before
import SLHttp
import SLREST

// After
import RoundTrip
import RoundTripREST
```

Add the `roundtrip-swift` package dependency, then replace the SwiftLibs products with `.product(name: "RoundTrip", package: "roundtrip-swift")` and `.product(name: "RoundTripREST", package: "roundtrip-swift")`. The main REST names stay the same: `RestClient`, `NetworkService`, `BaseURLProvider`, `ApiKeyProvider`, and `DefaultHttpHeaderProvider`.

RoundTripREST supports Apple platforms only. Remove Linux targets that used `SLREST` before moving to the extracted package.
