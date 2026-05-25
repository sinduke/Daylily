// swift-tools-version: 6.0

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Daylily",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "Daylily", targets: ["Daylily"]),
        .library(name: "DaylilyCore", targets: ["DaylilyCore"]),
        .library(name: "DaylilyJSON", targets: ["DaylilyJSON"]),
        .library(name: "DaylilyNIO", targets: ["DaylilyNIO"]),
        .executable(name: "HelloDaylily", targets: ["HelloDaylily"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.74.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0-latest"),
    ],
    targets: [
        .target(name: "DaylilyCore"),
        .target(
            name: "DaylilyJSON",
            dependencies: ["DaylilyCore"]
        ),
        .macro(
            name: "DaylilyMacros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "DaylilyNIO",
            dependencies: [
                "DaylilyCore",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ]
        ),
        .target(
            name: "Daylily",
            dependencies: [
                "DaylilyCore",
                "DaylilyJSON",
                "DaylilyMacros",
                "DaylilyNIO",
            ]
        ),
        .executableTarget(
            name: "HelloDaylily",
            dependencies: ["Daylily"]
        ),
    ]
)
