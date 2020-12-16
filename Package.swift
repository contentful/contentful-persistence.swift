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
        .package(url: "https://github.com/contentful/contentful.swift", .upToNextMajor(from: "5.4.1"))
    ],
    targets: [
        .target(
            name: "ContentfulPersistence",
            dependencies: [
                "Contentful"
            ])
    ]

)
