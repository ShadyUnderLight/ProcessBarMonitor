// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ProcessBarMonitor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ProcessBarMonitor", targets: ["ProcessBarMonitor"])
    ],
    targets: [
        .target(
            name: "CSensors",
            path: "Sources/CSensors",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "ProcessBarMonitor",
            dependencies: ["CSensors"],
            path: "Sources/ProcessBarMonitor"
        )
    ]
)
