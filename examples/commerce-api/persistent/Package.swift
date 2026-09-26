// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "PersistentCommerce",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PersistentCommerce", targets: ["PersistentCommerce"])],
    dependencies: [
        .package(name: "Daylily", path: "../../.."),
        .package(name: "DaylilyCommerceAPI", path: ".."),
        .package(url: "https://github.com/vapor/postgres-nio.git", exact: "1.33.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.6.0"),
    ],
    targets: [
        .target(name: "PersistentCommerceCore", dependencies: [
            .product(name: "AppCore", package: "DaylilyCommerceAPI"),
            .product(name: "Daylily", package: "Daylily"),
            .product(name: "PostgresNIO", package: "postgres-nio"),
            .product(name: "Logging", package: "swift-log"),
        ]),
        .executableTarget(name: "PersistentCommerce", dependencies: [
            "PersistentCommerceCore",
            .product(name: "DaylilyServiceLifecycle", package: "Daylily"),
            .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
        ]),
        .testTarget(name: "PersistentCommerceTests", dependencies: [
            "PersistentCommerceCore",
            .product(name: "DaylilyTesting", package: "Daylily"),
        ]),
    ]
)
