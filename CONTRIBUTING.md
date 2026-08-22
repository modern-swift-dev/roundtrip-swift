# Contributing

RoundTrip is in its first extraction from SwiftLibs. Keep changes focused on the HTTP or REST library, and update the matching DocC guide when a public API changes.

Run the repository checks described by the project tooling before opening a change. Do not edit generated documentation output by hand. The project has no published remote, release process, or hosted site yet, so this document intentionally makes no claims about them.

When reporting a bug, include the platform, the request or response shape when safe to share, and a small reproducer. For behavior changes, add tests that exercise the URL loading path without relying on a live service.

## Platform validation

RoundTrip supports watchOS 11. The watchOS lane runs the remaining compatible suites. Five Mocker-backed test files use `#if !os(watchOS)` because watchOS does not route POST and upload requests through a custom `URLProtocol`. The other Apple platforms run those tests.
