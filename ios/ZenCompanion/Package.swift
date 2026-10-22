// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZenCompanion",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17),
    ],
    products: [
        .library(name: "ZenCompanionCore", targets: ["ZenCompanionCore"]),
        .executable(name: "ZenCompanionApp", targets: ["ZenCompanionApp"]),
    ],
    targets: [
        .target(
            name: "ZenCompanionCore",
            path: "Sources/ZenCompanionCore"
        ),
        .executableTarget(
            name: "ZenCompanionApp",
            dependencies: ["ZenCompanionCore"],
            path: "Sources/ZenCompanionApp"
        ),
        .testTarget(
            name: "ZenCompanionCoreTests",
            dependencies: ["ZenCompanionCore"],
            path: "Tests/ZenCompanionCoreTests"
        ),
    ]
)
