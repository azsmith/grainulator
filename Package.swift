// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Grainulator",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Grainulator",
            targets: ["Grainulator"]
        ),
    ],
    dependencies: [
        // Add dependencies here as needed
    ],
    targets: [
        // Main application target
        .executableTarget(
            name: "Grainulator",
            dependencies: ["GrainulatorCore"],
            path: "Source/Application",
            exclude: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Resources/Info.plist"
                ])
            ]
        ),

        // Core audio and synthesis engine
        .target(
            name: "GrainulatorCore",
            dependencies: [],
            path: "Source/Audio",
            exclude: [],
            sources: ["Core/", "Synthesis/", "Effects/"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("Core"),
                .headerSearchPath("Synthesis"),
                .headerSearchPath("Synthesis/Rings"),
                .headerSearchPath("Synthesis/Plaits"),
                .headerSearchPath("Synthesis/Plaits/Core"),
                .headerSearchPath("Synthesis/Plaits/Engines"),
                .headerSearchPath("Synthesis/Plaits/stmlib"),
                .headerSearchPath("Synthesis/Granular"),
                .define("AUDIO_SAMPLE_RATE", to: "48000"),
                .define("MAX_GRAINS", to: "128"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),

        // UI components
        .target(
            name: "GrainulatorUI",
            dependencies: ["GrainulatorCore"],
            path: "Source/UI",
            exclude: []
        ),

        // Tests
        .testTarget(
            name: "GrainulatorTests",
            dependencies: ["GrainulatorCore", "Grainulator"],
            path: "Tests"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
