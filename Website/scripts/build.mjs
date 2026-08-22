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
    `<section class="hero"><p class="eyebrow">Swift HTTP and REST libraries</p><h1>RoundTrip</h1><p>RoundTrip provides the HTTP layer. RoundTripREST adds REST client support.</p><p><a class="button" href="${path("/documentation/")}">Read the documentation</a></p></section>
     <section><h2>Apple platforms</h2><p>macOS 15, iOS 18, tvOS 18, watchOS 11, and visionOS 2.</p></section>`
);

const documentation = page(
    "RoundTrip documentation",
    "RoundTrip and RoundTripREST API references.",
    `<section><p class="eyebrow">Documentation</p><h1>API references</h1><div class="cards"><article><h2>RoundTrip</h2><p>The HTTP library.</p><a href="${path("/api/roundtrip/")}">Open the API reference</a></article><article><h2>RoundTripREST</h2><p>REST client support built on RoundTrip.</p><a href="${path("/api/roundtrip-rest/")}">Open the API reference</a></article></div></section>`
);

const examples = page(
    "RoundTrip examples",
    "RoundTrip package examples.",
    `<section><p class="eyebrow">Examples</p><h1>Examples</h1><p>Run the checked-in examples with:</p><pre><code>swift test --package-path Examples</code></pre><p>The examples use the local package checkout.</p></section>`
);

await rm(outputDirectory, { recursive: true, force: true });
await mkdir(resolve(outputDirectory, "documentation"), { recursive: true });
await mkdir(resolve(outputDirectory, "examples"), { recursive: true });
await writeFile(resolve(outputDirectory, "index.html"), home);
await writeFile(resolve(outputDirectory, "documentation", "index.html"), documentation);
await writeFile(resolve(outputDirectory, "examples", "index.html"), examples);
await cp(publicDirectory, outputDirectory, { recursive: true });
