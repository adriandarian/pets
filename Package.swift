// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClaudePet",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ClaudePetCore", targets: ["ClaudePetCore"]),
        .executable(name: "ClaudePet", targets: ["ClaudePet"])
    ],
    targets: [
        .target(name: "ClaudePetCore"),
        .executableTarget(
            name: "ClaudePet",
            dependencies: ["ClaudePetCore"]
        ),
        .testTarget(
            name: "ClaudePetCoreTests",
            dependencies: ["ClaudePetCore"]
        )
    ]
)
