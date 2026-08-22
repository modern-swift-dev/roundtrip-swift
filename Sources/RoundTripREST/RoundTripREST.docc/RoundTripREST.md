# ``RoundTripREST``

Build API clients on top of RoundTrip's request and transfer types.

## Overview

``RestClient`` combines a base URL provider, optional API key and default header providers, a network service, JSON coders, and an error publisher. It validates expected status codes before returning raw or decoded responses.

RoundTripREST supports iOS 18, macOS 15, tvOS 18, watchOS 11, and visionOS 2. It does not support Linux.

The watchOS lane runs the remaining compatible suites. Five Mocker-backed test files use `#if !os(watchOS)` because watchOS does not route POST and upload requests through a custom `URLProtocol`. The other Apple platforms run those tests.

## Topics

### Essentials

- <doc:RESTClient>
- <doc:ErrorsAndDecoding>
- <doc:CancellationAndConcurrency>

### Development

- <doc:Testing>
- <doc:MigrationFromSwiftLibs>
