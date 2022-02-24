// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TinyNetworking",
    products: [
        .library(
            name: "TinyNetworking",
            targets: ["TinyNetworking"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "TinyNetworking",
            dependencies: []),
        .testTarget(
            name: "TinyNetworkingTests",
            dependencies: ["TinyNetworking"]),
    ]
)
