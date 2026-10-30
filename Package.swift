// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NextUp",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "NextUp", targets: ["NextUp"])],
    targets: [
        .target(name: "NextUpCore"),
        .executableTarget(name: "NextUp", dependencies: ["NextUpCore"]),
        .testTarget(name: "NextUpCoreTests", dependencies: ["NextUpCore"])
    ]
)
