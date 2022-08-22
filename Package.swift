// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Statsig",
    platforms: [.iOS(.v10), .tvOS(.v10), .macOS(.v10_12)],
    products: [
        .library(
            name: "Statsig",
            targets: ["Statsig"]),
    ],
    dependencies: [
        .package(url: "https://github.com/AliSoftware/OHHTTPStubs.git", .upToNextMajor(from: "9.1.0")),
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "9.0.0")),
        .package(url: "https://github.com/Quick/Quick.git", .upToNextMajor(from: "3.1.2")),
    ],
    targets: [
        .target(
            name: "Statsig",
            dependencies: [.target(name: "StatsigInternalObjC")],
            path: "Sources/Statsig"),
        .target(name: "StatsigInternalObjC", path: "Sources/StatsigInternalObjC"),
        .testTarget(
            name: "StatsigTests",
            dependencies: ["Statsig", "Quick", "Nimble", "OHHTTPStubs", .product(name: "OHHTTPStubsSwift", package: "OHHTTPStubs")]),
    ],
    swiftLanguageVersions: [.v5]
)
