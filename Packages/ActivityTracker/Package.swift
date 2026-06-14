// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "ActivityTracker",
  platforms: [
    .iOS(.v26),
    .watchOS(.v26),
    .macOS(.v13),
  ],
  products: [
    .library(name: "Shared", targets: ["Shared"]),
    .library(name: "Database", targets: ["Database"]),
    .library(name: "ActivityWidgetUI", targets: ["ActivityWidgetUI"]),
    .library(name: "ActivityIntents", targets: ["ActivityIntents"]),
    .library(name: "DayListFeature", targets: ["DayListFeature"]),
    .library(name: "ActivitySessionFeature", targets: ["ActivitySessionFeature"]),
    .library(name: "AppFeature", targets: ["AppFeature"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.17.0"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.0"),
    .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.0"),
  ],
  targets: [
    .target(
      name: "Shared"
    ),
    .target(
      name: "Database",
      dependencies: [
        "Shared",
        .product(name: "SQLiteData", package: "sqlite-data"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "ActivityWidgetUI",
      dependencies: ["Shared"]
    ),
    .target(
      name: "ActivityIntents",
      dependencies: [
        "Database",
        "Shared",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "DayListFeature",
      dependencies: [
        "Database",
        "ActivityWidgetUI",
        "Shared",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "ActivitySessionFeature",
      dependencies: [
        "Database",
        "Shared",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "AppFeature",
      dependencies: [
        "DayListFeature",
        "ActivitySessionFeature",
        "ActivityIntents",
        "Database",
        "Shared",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "DatabaseTests",
      dependencies: [
        "Database",
        "Shared",
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
      ]
    ),
    .testTarget(
      name: "ActivityWidgetUITests",
      dependencies: [
        "ActivityWidgetUI",
      ]
    ),
    .testTarget(
      name: "ActivityIntentsTests",
      dependencies: [
        "ActivityIntents",
        "Database",
        "Shared",
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
      ]
    ),
    .testTarget(
      name: "DayListFeatureTests",
      dependencies: [
        "DayListFeature",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "CustomDump", package: "swift-custom-dump"),
      ]
    ),
    .testTarget(
      name: "ActivitySessionFeatureTests",
      dependencies: [
        "ActivitySessionFeature",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "CustomDump", package: "swift-custom-dump"),
      ]
    ),
    .testTarget(
      name: "AppFeatureTests",
      dependencies: [
        "AppFeature",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "CustomDump", package: "swift-custom-dump"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
