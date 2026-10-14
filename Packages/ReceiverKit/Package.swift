// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ReceiverKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "ReceiverKit", targets: ["ReceiverKit"])],
    targets: [
        .target(name: "ReceiverKit"),
        .testTarget(name: "ReceiverKitTests", dependencies: ["ReceiverKit"]),
    ]
)
