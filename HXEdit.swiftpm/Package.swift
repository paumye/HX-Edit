// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "HXEdit",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "HXEdit",
            targets: ["AppModule"],
            bundleIdentifier: "com.paumye.HXEdit",
            teamIdentifier: "",
            displayVersion: "0.1",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .guitar),
            accentColor: .presetColor(.orange),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
