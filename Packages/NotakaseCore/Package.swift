// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NotakaseCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "NotakaseCore", targets: ["NotakaseCore"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/automerge/automerge-swift",
            from: "0.5.2"),
    ],
    targets: [
        .target(
            name: "NotakaseCore",
            dependencies: [
                .product(name: "Automerge", package: "automerge-swift"),
            ]),
        .testTarget(name: "NotakaseCoreTests", dependencies: ["NotakaseCore"]),
    ]
)
