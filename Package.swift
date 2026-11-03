// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AiBoxCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "AiBoxCore", targets: ["AiBoxCore"])],
    targets: [
        .target(name: "AiBoxCore", path: "Sources/AiBoxCore"),
        .testTarget(name: "AiBoxCoreTests", dependencies: ["AiBoxCore"],
                    path: "Tests/AiBoxCoreTests")
    ]
)
