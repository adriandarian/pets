// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Pets",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PetsCore", targets: ["PetsCore"]),
        .executable(name: "Pets", targets: ["Pets"])
    ],
    targets: [
        .target(
            name: "PetsCore",
            resources: [.copy("Resources/PetArt")]
        ),
        .executableTarget(
            name: "Pets",
            dependencies: ["PetsCore"]
        ),
        .testTarget(
            name: "PetsCoreTests",
            dependencies: ["PetsCore"]
        )
    ]
)
