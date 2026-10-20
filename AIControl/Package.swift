// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AIControl",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "AIControl", targets: ["AIControl"])],
    targets: [
        .target(name: "AIControlCore", resources: [.process("Resources")]),
        .executableTarget(
            name: "AIControl",
            dependencies: ["AIControlCore"],
            resources: [.copy("Resources/AI Control logo.png")]
        ),
        .testTarget(name: "AIControlCoreTests", dependencies: ["AIControlCore"])
    ]
)
