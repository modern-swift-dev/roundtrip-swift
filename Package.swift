// swift-tools-version: 6.0

import PackageDescription

let strictConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency")
]

let applePlatforms: [Platform] = [
    .iOS,
    .macOS,
    .tvOS,
    .watchOS,
    .visionOS
]

let kronosPlatforms: [Platform] = [
    .iOS,
    .macOS,
    .tvOS,
    .visionOS
]

let package = Package(
    name: "RoundTrip",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    products: [
        .library(name: "RoundTrip", targets: ["RoundTrip"]),
        .library(name: "RoundTripREST", targets: ["RoundTripREST"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-docc-plugin",
            exact: "1.5.0"
        ),
        .package(
            url: "https://github.com/MobileNativeFoundation/Kronos.git",
            exact: "4.3.1"
        ),
        .package(
            url: "https://github.com/WeTransfer/Mocker.git",
            exact: "3.0.2"
        )
    ],
    targets: [
        .target(
            name: "RoundTrip",
            dependencies: [
                .product(
                    name: "Kronos",
                    package: "Kronos",
                    condition: .when(platforms: kronosPlatforms)
                )
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "RoundTripREST",
            dependencies: ["RoundTrip"],
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "RoundTripTests",
            dependencies: [
                "RoundTrip",
                .product(
                    name: "Mocker",
                    package: "Mocker",
                    condition: .when(platforms: applePlatforms)
                )
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "RoundTripRESTTests",
            dependencies: [
                "RoundTripREST",
                .product(
                    name: "Mocker",
                    package: "Mocker",
                    condition: .when(platforms: applePlatforms)
                )
            ],
            swiftSettings: strictConcurrencySettings
        )
    ],
    swiftLanguageModes: [.v6]
)
