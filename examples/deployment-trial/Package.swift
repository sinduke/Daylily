// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "DaylilyDeploymentTrial",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "TrialServer", targets: ["TrialServer"])],
    dependencies: [
        // DAYLILY_DEPENDENCY_START
        .package(name: "Daylily", path: "../.."),
        // DAYLILY_DEPENDENCY_END
    ],
    targets: [
        .executableTarget(name: "TrialServer", dependencies: [
            .product(name: "Daylily", package: "Daylily"),
        ]),
    ]
)
