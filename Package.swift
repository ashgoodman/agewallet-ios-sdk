// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgeWalletSDK",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "AgeWalletSDK",
            targets: ["AgeWalletSDK"]
        ),
    ],
    targets: [
        .target(
            name: "AgeWalletSDK",
            dependencies: [],
            path: "Sources/AgeWalletSDK"
        ),
        .testTarget(
            name: "AgeWalletSDKTests",
            dependencies: ["AgeWalletSDK"],
            path: "Tests/AgeWalletSDKTests"
        ),
    ]
)
