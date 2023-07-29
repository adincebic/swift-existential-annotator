// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ExistentialAnnotator",
    platforms: [.macOS(.v12)],
    products: [
        .executable(
            name: "existential-annotator",
            targets: ["ExistentialAnnotator"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax", exact: "508.0.1"),
        .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.2.2")
    ],
    targets: [
        .executableTarget(
            name: "ExistentialAnnotator",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxParser", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
        .testTarget(
            name: "ExistentialAnnotatorTests",
            dependencies: ["ExistentialAnnotator"]),
    ]
)
