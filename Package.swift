// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Afterworks",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "AfterworksCore", targets: ["AfterworksCore"])],
    targets: [
        .target(name: "AfterworksCore"),
        .testTarget(name: "AfterworksCoreTests", dependencies: ["AfterworksCore"])
    ]
)
