// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Storyteller",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "Storyteller", path: "Sources/Storyteller", swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
