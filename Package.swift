// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyBetterLife",
    defaultLocalization: "pt-BR",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "MyBetterLifeCore",
            targets: ["MyBetterLifeCore"]
        ),
        .library(
            name: "MyBetterLifeUI",
            targets: ["MyBetterLifeUI"]
        ),
        .executable(
            name: "MyBetterLifeMacApp",
            targets: ["MyBetterLifeMacApp"]
        )
    ],
    targets: [
        .target(
            name: "MyBetterLifeCore",
            path: "Sources/MyBetterLifeCore"
        ),
        .target(
            name: "MyBetterLifeUI",
            dependencies: ["MyBetterLifeCore"],
            path: "Sources/MyBetterLifeUI"
        ),
        .executableTarget(
            name: "MyBetterLifeMacApp",
            dependencies: ["MyBetterLifeCore", "MyBetterLifeUI"],
            path: "Sources/MyBetterLifeMacApp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MyBetterLifeCoreTests",
            dependencies: ["MyBetterLifeCore"],
            path: "Tests/MyBetterLifeCoreTests"
        )
    ]
)
