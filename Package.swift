// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapacitorBraintreePluginSmf",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "CapacitorBraintreePluginSmf",
            targets: ["SMFCapacitorBraintreePluginPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "SMFCapacitorBraintreePluginPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/SMFCapacitorBraintreePluginPlugin"),
        .testTarget(
            name: "SMFCapacitorBraintreePluginPluginTests",
            dependencies: ["SMFCapacitorBraintreePluginPlugin"],
            path: "ios/Tests/SMFCapacitorBraintreePluginPluginTests")
    ]
)