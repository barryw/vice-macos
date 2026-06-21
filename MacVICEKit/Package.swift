// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacVICEKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "MacVICEKit",
            targets: ["MacVICEKit"]
        )
    ],
    targets: [
        .target(
            name: "CMacVICEEngineBridge"
        ),
        .target(
            name: "MacVICEKit",
            dependencies: ["CMacVICEEngineBridge"]
        ),
        .testTarget(
            name: "MacVICEKitTests",
            dependencies: ["MacVICEKit"]
        )
    ],
    swiftLanguageModes: [.v6]
)
