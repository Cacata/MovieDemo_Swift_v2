// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RxSearchExercise",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "RxSearchExercise", targets: ["RxSearchExercise"])],
    dependencies: [.package(url: "https://github.com/ReactiveX/RxSwift.git", exact: "6.9.1")],
    targets: [
        .target(name: "RxSearchExercise", dependencies: [.product(name: "RxSwift", package: "RxSwift")]),
        .testTarget(name: "RxSearchExerciseTests", dependencies: [
            "RxSearchExercise",
            .product(name: "RxTest", package: "RxSwift"),
        ]),
    ]
)
