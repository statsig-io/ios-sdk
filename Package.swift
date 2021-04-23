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
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "9.0.0")),
        .package(url: "https://github.com/Quick/Quick.git", .upToNextMajor(from: "3.1.2")),
    ],
    targets: [
        .target(
            name: "Statsig",
            dependencies: [],
            path: "Sources/Statsig"),
        .testTarget(
            name: "StatsigTests",
            dependencies: ["Statsig", "Quick", "Nimble"]),
    ],
    swiftLanguageVersions: [.v5]
)
