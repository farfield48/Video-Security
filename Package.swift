// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VideoSecurity",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "VideoSecurity",
            path: "Sources/VideoSecurity",
            exclude: ["Info.plist"],
            swiftSettings: [
                .unsafeFlags(["-Osize"])
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("Accelerate"),
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit")
            ]
        )
    ]
)
