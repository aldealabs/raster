// swift-tools-version:5.1

// requires SE-0271

import PackageDescription

let package = Package(
    name: "Raster",
    platforms: [.macOS(.v10_13), .iOS(.v11), .tvOS(.v13)],
    products: [
        .library(
            name: "Raster",
            targets: ["Raster"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Raster",
            dependencies: ["RasterObjectiveC"]),
        .target(
            name: "RasterObjectiveC",
            dependencies: []),
        .target(
            name: "RasterTestHelpers",
            dependencies: ["Raster"],
            path: "Tests/RasterTestHelpers"),
        .testTarget(
            name: "RasterTests",
            dependencies: ["Raster", "RasterTestHelpers"]),
    ],
    cxxLanguageStandard: .cxx14
)
