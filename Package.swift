// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "ContentfulPersistence",
    products: [
        .library(
            name: "ContentfulPersistence",
            targets: ["ContentfulPersistence"])
    ],
    dependencies: [
        .package(url: "https://github.com/contentful/contentful.swift", .upToNextMinor(from: "2.0.0-alpha3"))
    ],
    targets: [
        .target(
            name: "ContentfulPersistence",
            dependencies: [
                "Contentful"
            ])
    ]

)
