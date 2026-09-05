// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StudioCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "StudioCore", targets: ["StudioCore"])],
    targets: [
        .target(name: "StudioCore"),
        .testTarget(name: "StudioCoreTests", dependencies: ["StudioCore"])
    ]
)
