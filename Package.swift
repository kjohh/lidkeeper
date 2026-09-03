// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LidKeeper",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "LidKeeper", path: "Sources/LidKeeper")
    ]
)
