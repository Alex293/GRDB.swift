// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

var swiftSettings: [SwiftSetting] = [
    .define("SQLITE_ENABLE_FTS5"),
]
var cSettings: [CSetting] = []
var dependencies: [PackageDescription.Package.Dependency] = []

// Don't rely on those environment variables. They are ONLY testing conveniences:
// $ SQLITE_ENABLE_PREUPDATE_HOOK=1 make test_SPM
if ProcessInfo.processInfo.environment["SQLITE_ENABLE_PREUPDATE_HOOK"] == "1" {
    swiftSettings.append(.define("SQLITE_ENABLE_PREUPDATE_HOOK"))
    cSettings.append(.define("GRDB_SQLITE_ENABLE_PREUPDATE_HOOK"))
}

// The SPI_BUILDER environment variable enables documentation building
// on <https://swiftpackageindex.com/groue/GRDB.swift>. See
// <https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2122>
// for more information.
//
// SPI_BUILDER also enables the `make docs-localhost` command.
if ProcessInfo.processInfo.environment["SPI_BUILDER"] == "1" {
    dependencies.append(.package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"))
}

var targetDependencies: [Target.Dependency] = ["GRDBSQLite"]


//var GRDBCIPHER = ProcessInfo.processInfo.environment["GRDBCIPHER"]
var GRDBCIPHER: String? = "https://github.com/Alex293/swift-sqlcipher.git#main"
// e.g.:
//GRDBCIPHER="https://github.com/skiptools/swift-sqlcipher.git#1.2.1"
if let SQLCipherRepo = GRDBCIPHER?.split(separator: "#").first,
    let SQLCipherVersion = GRDBCIPHER?.split(separator: "#").last,
    let SQLCipherRepoURL = URL(string: SQLCipherRepo.description) {
    swiftSettings.append(.define("GRDBCIPHER"))
    targetDependencies = [.product(name: "SQLCipher", package: SQLCipherRepoURL.deletingPathExtension().lastPathComponent)]
    if let version = Version(SQLCipherVersion.description) { // numeric version
        dependencies.append(.package(url: SQLCipherRepoURL.absoluteString, from: version))
    } else { // branch
        dependencies.append(.package(url: SQLCipherRepoURL.absoluteString, branch: SQLCipherVersion.description))
    }
}

let package = Package(
    name: "GRDB",
    defaultLocalization: "en", // for tests
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v7),
    ],
    products: [
        .library(name: "GRDBSQLite", targets: ["GRDBSQLite"]),
        .library(name: "GRDB", targets: ["GRDB"]),
        .library(name: "GRDB-dynamic", type: .dynamic, targets: ["GRDB"]),
    ],
    dependencies: dependencies,
    targets: [
        .systemLibrary(
            name: "GRDBSQLite",
            providers: [.apt(["libsqlite3-dev"])]),
        .target(
            name: "GRDB",
            dependencies: targetDependencies,
            path: "GRDB",
            resources: [.copy("PrivacyInfo.xcprivacy")],
            cSettings: cSettings,
            swiftSettings: swiftSettings),
        .testTarget(
            name: "GRDBTests",
            dependencies: ["GRDB"],
            path: "Tests",
            exclude: [
                "CocoaPods",
                "Crash",
                "CustomSQLite",
                "GRDBManualInstall",
                "GRDBTests/getThreadsCount.c",
                "Info.plist",
                "Performance",
                "SPM",
                "Swift6Migration",
                "generatePerformanceReport.rb",
                "parsePerformanceTests.rb",
            ],
            resources: [
                .copy("GRDBTests/Betty.jpeg"),
                .copy("GRDBTests/InflectionsTests.json"),
                .copy("GRDBTests/Issue1383.sqlite"),
            ],
            cSettings: cSettings,
            swiftSettings: swiftSettings + [
                // Tests still use the Swift 5 language mode.
                .swiftLanguageMode(.v5),
                .enableUpcomingFeature("InferSendableFromCaptures"),
                .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
            ])
    ],
    swiftLanguageModes: [.v6]
)

// The GRDB_PERFORMANCE_TESTS environment variable enables
// the performance tests to be included in the package, which can be run with:
// GRDB_PERFORMANCE_TESTS=1 swift test --filter GRDBPerformanceTests
if ProcessInfo.processInfo.environment["GRDB_PERFORMANCE_TESTS"] == "1" {
    package.targets.append(
        Target.testTarget(
            name: "GRDBPerformanceTests",
            dependencies: ["GRDB"],
            path: "Tests/Performance/GRDBPerformance",
            cSettings: cSettings,
            swiftSettings: swiftSettings + [
                // Tests still use the Swift 5 language mode.
                .swiftLanguageMode(.v5),
                .enableUpcomingFeature("InferSendableFromCaptures"),
                .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
            ])
    )
}

