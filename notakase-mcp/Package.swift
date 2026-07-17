// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "notakase-mcp",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../Packages/NotakaseCore")
    ],
    targets: [
        .executableTarget(
            name: "notakase-mcp",
            dependencies: [
                .product(name: "NotakaseCore", package: "NotakaseCore")
            ])
    ]
)
