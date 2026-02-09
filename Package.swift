// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SharedCalendarApp",
    // This line fixes the "available in macOS..." errors by setting the minimum requirement
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
    ],
    targets: [
        // Targets are the basic building blocks of a package.
        .executableTarget(
            name: "SharedCalendarApp",
            dependencies: [])
    ]
)
