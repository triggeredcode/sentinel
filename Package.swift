// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Sentinel",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Sentinel", targets: ["Sentinel"])
    ],
    targets: [
        .executableTarget(
            name: "Sentinel",
            path: "Sources/Sentinel",
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
