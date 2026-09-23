// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SquatCounter",
    platforms: [.iOS(.v17)],
    products: [.library(name: "SquatCounterCore", targets: ["SquatCounterCore"])],
    dependencies: [],
    targets: [
        .target(name: "SquatCounterCore"),
        .testTarget(name: "SquatCounterCoreTests", dependencies: ["SquatCounterCore"])
    ]
)
