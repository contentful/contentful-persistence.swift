import PackageDescription

let package = Package(
    name: "Contentful",
    dependencies: [
        .Package(url: "https://github.com/contentful/contentful.swift", majorVersion: 0)
    ]
)

