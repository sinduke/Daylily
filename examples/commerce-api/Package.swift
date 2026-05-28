// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DaylilyCommerceAPI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "AppCore", targets: ["AppCore"]),
        .executable(name: "App", targets: ["App"]),
    ],
    dependencies: [
        // DAYLILY_DEPENDENCY_START
        .package(name: "Daylily", path: "../.."),
        // DAYLILY_DEPENDENCY_END
    ],
    targets: [
        .target(
            name: "AppCore",
            dependencies: [
                .product(name: "Daylily", package: "Daylily"),
            ]
        ),
        .executableTarget(
            name: "App",
            dependencies: [
                "AppCore",
                .product(name: "Daylily", package: "Daylily"),
            ]
        ),
        .testTarget(
            name: "AppCoreTests",
            dependencies: [
                "AppCore",
                .product(name: "DaylilyTesting", package: "Daylily"),
            ]
        ),
    ]
)
