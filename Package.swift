// swift-tools-version:6.1

import PackageDescription

let package = Package(
    name: "NotiWindow",
    platforms: [
        .iOS("18.6"),
    ],
    products: [
        .library(name: "NotiWindow", targets: ["NotiWindow"]),
    ],
    targets: [
        .target(name: "NotiWindow"),
        .testTarget(name: "NotiWindowTests", dependencies: ["NotiWindow"]),
    ],
    swiftLanguageModes: [.v6]
)
