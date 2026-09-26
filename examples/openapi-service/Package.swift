// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "DaylilyOpenAPIExample",
    platforms: [.macOS(.v14)],
    dependencies: [
        // DAYLILY_DEPENDENCY_START
        .package(name: "Daylily", path: "../.."),
        // DAYLILY_DEPENDENCY_END
        .package(url: "https://github.com/apple/swift-openapi-generator.git", exact: "1.13.1"),
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.12.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession.git", exact: "1.3.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.13.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.11.0"),
    ],
    targets: [
        .executableTarget(name: "ExportSchema", dependencies: [
            .product(name: "DaylilyCore", package: "Daylily"),
            .product(name: "DaylilyOpenAPI", package: "Daylily"),
        ]),
        .target(name: "GeneratedAPI", dependencies: [
            .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        ], plugins: [.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")]),
        .executableTarget(name: "App", dependencies: [
            "GeneratedAPI",
            .product(name: "DaylilyCore", package: "Daylily"),
            .product(name: "DaylilyOpenAPITransport", package: "Daylily"),
            .product(name: "DaylilyServiceLifecycle", package: "Daylily"),
            .product(name: "DaylilyObservability", package: "Daylily"),
            .product(name: "DaylilySwiftLog", package: "Daylily"),
            .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            .product(name: "Logging", package: "swift-log"),
            .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
        ]),
    ]
)
