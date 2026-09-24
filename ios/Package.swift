// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SquatCounter",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SquatCounterCore", targets: ["SquatCounterCore"]),
        .executable(name: "ritmovis-eval", targets: ["RitmoVisEval"])
    ],
    dependencies: [],
    targets: [
        .target(name: "SquatCounterCore"),
        .executableTarget(name: "RitmoVisEval", dependencies: ["SquatCounterCore"]),
        .testTarget(name: "SquatCounterCoreTests", dependencies: ["SquatCounterCore"])
    ]
)
