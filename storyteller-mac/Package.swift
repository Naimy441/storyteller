// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Storyteller",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "Storyteller",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Storyteller",
            swiftSettings: [.swiftLanguageMode(.v5)],
            // Sparkle.framework is copied into Contents/Frameworks by build.sh.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
    ]
)
