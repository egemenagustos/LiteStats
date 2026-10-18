// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LiteStats",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "LiteStats",
            path: "Sources/LiteStats",
            swiftSettings: [.unsafeFlags(["-Osize"], .when(configuration: .release))]
        )
    ]
)
