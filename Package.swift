// swift-tools-version: 5.9

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
            name: "CMacVICEEngineBridge",
            path: "MacVICEKit/Sources/CMacVICEEngineBridge"
        ),
        .target(
            name: "MacVICEKit",
            dependencies: ["CMacVICEEngineBridge"],
            path: "MacVICEKit/Sources/MacVICEKit"
        ),
        .testTarget(
            name: "MacVICEKitTests",
            dependencies: ["MacVICEKit"],
            path: "MacVICEKit/Tests/MacVICEKitTests"
        )
    ]
)
