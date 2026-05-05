// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "HXEdit",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "HXEdit",
            targets: ["AppModule"],
            displayVersion: "1.0",
            bundleVersion: "1",
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            orientation: .all,
            capabilities: []
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
