// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PaperPulse",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "PaperCore", targets: ["PaperCore"])
    ],
    targets: [
        .target(name: "PaperCore"),
        .testTarget(
            name: "PaperCoreTests",
            dependencies: ["PaperCore"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
