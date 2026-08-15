// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftClient",
    platforms: [.macOS(.v13)],
    dependencies: [.package(name: "Raster", path: "../../..")],
    targets: [
        .executableTarget(
            name: "SwiftClient",
            dependencies: [.product(name: "Raster", package: "Raster")]
        )
    ]
)
