import PackageDescription

let package = Package(
    name: "Contentful",
    dependencies: [
        .Package(url: "https://github.com/contentful/contentful.swift", Version(0, 9, 3))
    ]
)
