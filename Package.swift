// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Statsig",
    platforms: [.iOS(.v10)],
    products: [
        .library(
            name: "Statsig",
            targets: ["Statsig"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Statsig",
            dependencies: [],
            path: "Sources/Statsig"),
        .testTarget(
            name: "StatsigTests",
            dependencies: ["Statsig"]),
    ],
    swiftLanguageVersions: [.v5]
)
