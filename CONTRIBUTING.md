# Contributing

RoundTrip is in its first extraction from SwiftLibs. Keep changes focused on the HTTP or REST library, and update the matching DocC guide when a public API changes.

Run the repository checks described by the project tooling before opening a change. Do not edit generated documentation output by hand. The [central documentation repository](https://github.com/modern-swift-dev/docs) owns Astro, the shared theme, and website/API generation. It builds from `main` daily and on manual runs. Edit page Markdown in `Documentation/Site/` and keep DocC catalogs beside the module sources. See the [docs README](https://github.com/modern-swift-dev/docs/blob/main/README.md) for local build and preview commands. Do not commit generated HTML to this repository.

When reporting a bug, include the platform, the request or response shape when safe to share, and a small reproducer. For behavior changes, add tests that exercise the URL loading path without relying on a live service.

## Platform validation

RoundTrip supports watchOS 11. The watchOS lane runs the remaining compatible suites. Five Mocker-backed test files use `#if !os(watchOS)` because watchOS does not route POST and upload requests through a custom `URLProtocol`. The other Apple platforms run those tests.
