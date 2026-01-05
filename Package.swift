// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "APIManager",
    platforms: [
        .iOS(.v13) // or higher based on your app
    ],
    products: [
        .library(
            name: "APIManager",
            targets: ["APIManager"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/SVProgressHUD/SVProgressHUD.git",
            from: "2.2.5"
        )
    ],
    targets: [
        .target(
            name: "APIManager",
            dependencies: [
                .product(name: "SVProgressHUD", package: "SVProgressHUD")
            ]
        ),
        .testTarget(
            name: "APIManagerTests",
            dependencies: ["APIManager"]
        ),
    ]
)
