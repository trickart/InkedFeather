// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "InkedFeather",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "Application", targets: ["Application"]),
        .executable(name: "Bootloader", targets: ["Bootloader"]),
    ],
    targets: [
        .target(
            name: "TrapHandler",
            publicHeadersPath: "include"
        ),
        .target(
            name: "HeapAllocator",
            swiftSettings: [
                .enableExperimentalFeature("Embedded"),
                .enableExperimentalFeature("Extern"),
            ]
        ),
        .target(
            name: "MemoryPrimitives",
            swiftSettings: [
                .enableExperimentalFeature("Embedded"),
                .enableExperimentalFeature("Extern"),
                .unsafeFlags(["-Xllvm", "-disable-loop-idiom-memcpy"]),
            ]
        ),
        .target(
            name: "SoftFloat",
            swiftSettings: [
                .enableExperimentalFeature("Embedded"),
                .enableExperimentalFeature("Extern"),
            ]
        ),
        .target(
            name: "Registers",
            exclude: ["esp32c3.svd"],
            swiftSettings: [
                .enableExperimentalFeature("Embedded"),
                .enableExperimentalFeature("Volatile"),
            ]
        ),
        .executableTarget(
            name: "Application",
            dependencies: [
                "Registers",
                "MemoryPrimitives",
                "HeapAllocator",
                "TrapHandler",
                "SoftFloat",
            ],
            swiftSettings: [
                .enableExperimentalFeature("Embedded"),
                .enableExperimentalFeature("Extern"),
                .enableExperimentalFeature("Volatile"),
            ]
        ),
        .executableTarget(
            name: "Bootloader",
            dependencies: [
                "Registers",
                "MemoryPrimitives",
                "HeapAllocator",
            ],
            swiftSettings: [
                .enableExperimentalFeature("Embedded"),
                .enableExperimentalFeature("Extern"),
                .enableExperimentalFeature("Volatile"),
            ]
        ),
    ]
)
