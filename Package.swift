// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "AutoCodeBar",
  defaultLocalization: "zh-Hans",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "AutoCodeBar", targets: ["AutoCodeBar"]),
    .library(name: "AutoCodeBarCore", targets: ["AutoCodeBarCore"])
  ],
  dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle.git", exact: "2.9.6")
  ],
  targets: [
    .target(
      name: "AutoCodeBarCore",
      linkerSettings: [
        .linkedLibrary("sqlite3")
      ]
    ),
    .executableTarget(
      name: "AutoCodeBar",
      dependencies: [
        "AutoCodeBarCore",
        .product(name: "Sparkle", package: "Sparkle")
      ]
    ),
    .testTarget(
      name: "AutoCodeBarCoreTests",
      dependencies: ["AutoCodeBarCore"]
    ),
    .testTarget(
      name: "AutoCodeBarTests",
      dependencies: ["AutoCodeBar"]
    )
  ],
  swiftLanguageModes: [.v5]
)
