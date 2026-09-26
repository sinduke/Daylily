// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DaylilyApplicationExercises",
    platforms: [.macOS(.v14)],
    dependencies: [.package(name: "Daylily", path: "../../..")],
    targets: [
        .target(name: "ApplicationExercises", dependencies: [
            .product(name: "DaylilyCore", package: "Daylily"),
            .product(name: "DaylilyJSON", package: "Daylily"),
            .product(name: "DaylilyOpenAPI", package: "Daylily"),
        ]),
        .testTarget(name: "ApplicationExercisesTests", dependencies: [
            "ApplicationExercises",
            .product(name: "DaylilyCore", package: "Daylily"),
            .product(name: "DaylilyOpenAPI", package: "Daylily"),
            .product(name: "DaylilyTesting", package: "Daylily"),
        ]),
    ]
)
