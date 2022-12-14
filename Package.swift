// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "xprojup",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .executable(
            name: "xprojup",
            targets: ["xprojup"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/phimage/XcodeProjKit.git", from: "3.0.3")
    ],
    targets: [
        .executableTarget(
            name: "xprojup",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "XcodeProjKit"]
        )
    ]
)
