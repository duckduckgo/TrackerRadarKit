// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TrackerRadarKit",
    products: [
        .library(
            name: "TrackerRadarKit",
            targets: ["TrackerRadarKit"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TrackerRadarKit",
            dependencies: []),
        .testTarget(
            name: "TrackerRadarKitTests",
            dependencies: ["TrackerRadarKit"]),
    ]
)
