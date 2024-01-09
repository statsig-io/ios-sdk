// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Statsig",
    platforms: [.watchOS(.v7), .iOS(.v10), .tvOS(.v10), .macOS(.v10_13)],
    products: [
        .library(
            name: "Statsig",
            targets: ["Statsig"]),
    ],
    dependencies: [
        .package(url: "https://github.com/AliSoftware/OHHTTPStubs.git", .upToNextMajor(from: "9.1.0")),
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "10.0.0")),
        .package(url: "https://github.com/Quick/Quick.git", .upToNextMajor(from: "5.0.0")),
        .package(url: "https://github.com/erikdoe/ocmock", .branch("master")),
    ],
    targets: [
        .target(
            name: "Statsig",
            dependencies: [.target(name: "StatsigInternalObjC")],
            path: "Sources/Statsig"),
        .target(name: "StatsigInternalObjC",
                     path: "Sources/StatsigInternalObjC",
                     publicHeadersPath: "include",
                     cSettings: [
                         .headerSearchPath("."),
                         .headerSearchPath("Private"),
                     ]),
        .testTarget(
            name: "StatsigTests",
            dependencies: ["Statsig", "Quick", "Nimble", "OHHTTPStubs", .product(name: "OHHTTPStubsSwift", package: "OHHTTPStubs")]),
        .testTarget(
            name: "StatsigObjcTests",
            dependencies: [.target(name: "Statsig"),.product(name: "OCMock", package: "ocmock")],
            resources: [.process("Resources")]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
