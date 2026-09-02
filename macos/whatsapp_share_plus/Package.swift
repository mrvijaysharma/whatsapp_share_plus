// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to
// build this package.

import PackageDescription

/// Swift Package Manager manifest for the macOS implementation.
///
/// The package and the CocoaPods podspec both build the same sources under
/// `Sources/whatsapp_share_plus`, so an app can integrate this plugin either
/// way. Flutter is moving to Swift Package Manager by default, and plugins
/// without a manifest will eventually stop building.
let package = Package(
    name: "whatsapp_share_plus",
    platforms: [
        .macOS(.v10_14)
    ],
    products: [
        .library(name: "whatsapp-share-plus", targets: ["whatsapp_share_plus"])
    ],
    dependencies: [
        // Resolved by the Flutter tool, which generates the FlutterFramework
        // package alongside this one when it assembles the app's packages.
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "whatsapp_share_plus",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
