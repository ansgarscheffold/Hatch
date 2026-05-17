// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Hatch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Hatch", targets: ["Hatch"])
    ],
    dependencies: [
        .package(name: "NSRemoteShell", path: "Sources/NSRemoteShell"),
        .package(name: "XTerminalUI", path: "Sources/XTerminalUI"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Hatch",
            dependencies: [
                .product(name: "XTerminalUI", package: "XTerminalUI"),
                "NSRemoteShell",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/Hatch",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
