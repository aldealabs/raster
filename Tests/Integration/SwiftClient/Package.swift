// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftClient",
    platforms: [.macOS(.v13)],
    dependencies: [.package(name: "MetalPetal", path: "../../..")],
    targets: [
        .executableTarget(
            name: "SwiftClient",
            dependencies: [.product(name: "MetalPetal", package: "MetalPetal")]
        )
    ]
)
