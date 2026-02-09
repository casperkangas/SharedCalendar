// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SharedCalendarApp",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // Using the version you selected
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.9.0")
    ],
    targets: [
        .executableTarget(
            name: "SharedCalendarApp",
            dependencies: [
                // Explicitly adding Core helps fix "No such module" errors
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
            ]
        )
    ]
)
