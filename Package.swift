// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DevKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "DevKitCore", targets: ["DevKitCore"]),
        .executable(name: "DevKit", targets: ["DevKitApp"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DevKitCore",
            dependencies: [],
            path: "Sources/DevKitCore"
        ),
        .executableTarget(
            name: "DevKitApp",
            dependencies: ["DevKitCore"],
            path: "Sources/DevKitApp"
        ),
        .executableTarget(
            name: "DevKitTestRunner",
            dependencies: ["DevKitCore"],
            path: "Sources/DevKitTestRunner"
        )
    ]
)
