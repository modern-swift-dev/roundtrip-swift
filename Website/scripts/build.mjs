import { cp, mkdir, rm, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const websiteDirectory = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const outputDirectory = resolve(websiteDirectory, "dist");
const publicDirectory = resolve(websiteDirectory, "public");
const basePath = (process.env.SITE_BASE_PATH ?? "/roundtrip-swift").replace(/\/$/, "");

function path(pathname) {
    return `${basePath}${pathname}`;
}

function page(title, description, content) {
    return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="${description}">
  <title>${title}</title>
  <link rel="stylesheet" href="${path("/styles.css")}">
</head>
<body>
  <header><nav><a href="${path("/")}">RoundTrip</a><a href="${path("/documentation/")}">Documentation</a><a href="${path("/examples/")}">Examples</a></nav></header>
  <main>${content}</main>
  <footer>RoundTrip supports macOS 15, iOS 18, tvOS 18, watchOS 11, and visionOS 2.</footer>
</body>
</html>`;
}

const home = page(
    "RoundTrip",
    "Swift HTTP and REST libraries for Apple platforms.",
    `<section class="hero"><p class="eyebrow">Swift HTTP and REST libraries</p><h1>RoundTrip</h1><p>RoundTrip constructs and sends HTTP requests. RoundTripREST adds a shared base URL, default headers, status validation, and JSON decoding.</p><p><a class="button" href="${path("/documentation/getting-started/")}">Get started</a> <a href="${path("/examples/")}">Read the examples</a></p></section>
     <section><h2>Apple platforms</h2><p>Use the same async API on macOS 15, iOS 18, tvOS 18, watchOS 11, and visionOS 2.</p></section>`
);

const documentation = page(
    "RoundTrip documentation",
    "RoundTrip guides and generated DocC API references.",
    `<section><p class="eyebrow">Documentation</p><h1>Guides and API references</h1><div class="cards"><article><h2>Getting started</h2><p>Install one or both products, construct a request, and execute it.</p><a href="${path("/documentation/getting-started/")}">Read the guide</a></article><article><h2>Examples</h2><p>Compare direct HTTP calls with a configured REST client.</p><a href="${path("/examples/")}">Read the examples</a></article><article><h2>RoundTrip</h2><p>Generated DocC for request builders, clients, responses, headers, and methods.</p><a href="${path("/api/roundtrip/documentation/roundtrip/")}">Open the API reference</a></article><article><h2>RoundTripREST</h2><p>Generated DocC for REST clients, providers, results, and API errors.</p><a href="${path("/api/roundtrip-rest/")}">Open the API reference</a></article></div></section>`
);

const gettingStarted = page(
    "Getting started with RoundTrip",
    "Install RoundTrip and send HTTP or REST requests.",
    `<section><p class="eyebrow">Getting started</p><h1>Build and send a request</h1><h2>Install the package</h2><pre><code>dependencies: [
    .package(
        url: "https://github.com/modern-swift-dev/roundtrip-swift.git",
        from: "1.0.0"
    )
]</code></pre><p>Add <code>RoundTrip</code> for direct HTTP operations. Add <code>RoundTripREST</code> when requests share a base URL and client configuration.</p><pre><code>.product(name: "RoundTrip", package: "roundtrip-swift"),
.product(name: "RoundTripREST", package: "roundtrip-swift")</code></pre><h2>Construct a request</h2><pre><code>let request = URLRequestBuilder(string: "https://example.com/users/42")!
    .setMethod(.get)
    .addHeader(.accept(.json))</code></pre><h2>Execute and decode</h2><pre><code>let response = try await HttpClient().execute(request: request)
try response.checkForStatusCodeValidity(validStatusCode: [200])

guard let user = response.payloadAs(User.self) else {
    throw ApiError.responseDecodingFailed(
        response.data,
        ApiError.emptyResponseBody
    )
}</code></pre><p>Continue with the <a href="${path("/examples/")}">examples</a> for query parameters and REST client configuration, or open the <a href="${path("/documentation/")}">DocC references</a> for every public symbol.</p></section>`
);

const examples = page(
    "RoundTrip examples",
    "Compiled RoundTrip request and REST client examples.",
    `<section><p class="eyebrow">Examples</p><h1>Compiled examples from the repository</h1><p>The <code>Examples</code> package uses the local checkout, so its source is checked against the current API.</p><h2>Run without network access</h2><pre><code>swift run --package-path Examples BasicUsage
swift test --package-path Examples</code></pre><p>The executable constructs a GET request for <code>https://example.com?source=basic-usage</code> and prepares the same request with <code>RestClient</code>. It sends nothing unless you pass <code>--execute</code>.</p><h2>Build a request</h2><pre><code>let request = builder
    .setMethod(.get)
    .addHeader(.accept(.json))
    .addQueryParam(name: "source", value: "basic-usage")
    .build()</code></pre><h2>Configure a REST client</h2><pre><code>let restClient = RestClient(
    baseURLProvider: ExampleBaseURLProvider(),
    apiKeyProvider: ExampleAPIKeyProvider(),
    service: NetworkService(),
    headerProvider: nil,
    errorSubject: PassthroughSubject&lt;ApiError, Never&gt;()
)</code></pre><p><a href="https://github.com/modern-swift-dev/roundtrip-swift/tree/main/Examples">Open the complete example source</a>.</p></section>`
);

await rm(outputDirectory, { recursive: true, force: true });
await mkdir(resolve(outputDirectory, "documentation"), { recursive: true });
await mkdir(resolve(outputDirectory, "documentation", "getting-started"), { recursive: true });
await mkdir(resolve(outputDirectory, "examples"), { recursive: true });
await writeFile(resolve(outputDirectory, "index.html"), home);
await writeFile(resolve(outputDirectory, "documentation", "index.html"), documentation);
await writeFile(resolve(outputDirectory, "documentation", "getting-started", "index.html"), gettingStarted);
await writeFile(resolve(outputDirectory, "examples", "index.html"), examples);
await cp(publicDirectory, outputDirectory, { recursive: true });
