// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Sentinel",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Sentinel", targets: ["Sentinel"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Sentinel",
            dependencies: [],
            path: "Sources/Sentinel",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ],
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Security"),
                .linkedFramework("IOKit"),
                .linkedFramework("Network")
            ]
        ),
        .testTarget(
            name: "SentinelTests",
            dependencies: ["Sentinel"],
            path: "Tests/SentinelTests"
        )
    ]
)
