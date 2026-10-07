// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "native_macos",
    platforms: [
        .macOS("12.0")
    ],
    products: [
        .library(name: "native-macos", targets: ["native_macos"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "native_macos",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
