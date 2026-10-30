// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RIBsMoviesExercise",
    platforms: [.iOS(.v17)],
    products: [.library(name: "RIBsMoviesExercise", targets: ["RIBsMoviesExercise"])],
    dependencies: [.package(url: "https://github.com/uber/RIBs-iOS.git", exact: "1.1.0")],
    targets: [
        .target(name: "RIBsMoviesExercise", dependencies: [.product(name: "RIBs", package: "RIBs-iOS")]),
        .testTarget(name: "RIBsMoviesExerciseTests", dependencies: ["RIBsMoviesExercise"]),
    ]
)
