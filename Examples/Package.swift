// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RoundTripExamples",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    dependencies: [
        .package(name: "RoundTrip", path: "..")
    ],
    targets: [
        .executableTarget(
            name: "BasicUsage",
            dependencies: [
                .product(name: "RoundTrip", package: "RoundTrip"),
                .product(name: "RoundTripREST", package: "RoundTrip")
            ],
            path: "Sources/BasicUsage"
        ),
        .testTarget(
            name: "BasicUsageTests",
            dependencies: [
                .target(name: "BasicUsage"),
                .product(name: "RoundTrip", package: "RoundTrip"),
                .product(name: "RoundTripREST", package: "RoundTrip")
            ],
            path: "Tests/BasicUsageTests"
        )
    ]
)
