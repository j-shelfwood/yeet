// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "yeet",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "yeet", targets: ["yeet"]),
        .library(name: "YeetCore", targets: ["YeetCore"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.3.0"
        ),
    ],
    targets: [
        // Rust-backed TiktokenFFI binary framework
        .binaryTarget(
            name: "TiktokenFFI",
            path: "Frameworks/TiktokenFFI.xcframework"
        ),

        // TiktokenSwift wrapper (local, LFS-free)
        .target(
            name: "TiktokenSwift",
            dependencies: ["TiktokenFFI"]
        ),

        // Executable target (thin CLI wrapper)
        .executableTarget(
            name: "yeet",
            dependencies: [
                "YeetCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        // Library target (contains business logic)
        .target(
            name: "YeetCore",
            dependencies: [
                "TiktokenSwift",
            ]
        ),

        // Tests
        .testTarget(
            name: "YeetCoreTests",
            dependencies: ["YeetCore"]
        ),
    ]
)
