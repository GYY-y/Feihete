// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Feihete",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "FeiheteCore"),
        .executableTarget(
            name: "Feihete",
            dependencies: ["FeiheteCore"]
        ),
        .executableTarget(
            name: "taptool",
            dependencies: ["FeiheteCore"]
        )
    ]
)
