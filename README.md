# contentful-persistence.swift

[![Version](https://img.shields.io/cocoapods/v/ContentfulPersistenceSwift.svg?style=flat)](http://cocoadocs.org/docsets/ContentfulPersistenceSwift)
[![License](https://img.shields.io/cocoapods/l/ContentfulPersistenceSwift.svg?style=flat)](http://cocoadocs.org/docsets/ContentfulPersistenceSwift)
[![Platform](https://img.shields.io/cocoapods/p/ContentfulPersistenceSwift.svg?style=flat)](http://cocoadocs.org/docsets/ContentfulPersistenceSwift)
[![Build Status](https://img.shields.io/travis/contentful/contentful-persistence.swift/master.svg?style=flat)](https://travis-ci.org/contentful/contentful-persistence.swift)
[![Coverage Status](https://img.shields.io/coveralls/contentful/contentful-persistence.swift.svg)](https://coveralls.io/github/contentful/contentful-persistence.swift)

Simplified persistence for the [Contentful][1] [Swift SDK][2].

[Contentful][1] is a content management platform for web applications, mobile apps and connected devices. It allows you to create, edit & manage content in the cloud and publish it anywhere via powerful API. Contentful offers tools for managing editorial teams and enabling cooperation between organizations.

## Usage

The `ContentfulSynchronizer` manages the state of your synchronization with a Space:

```swift
let sync = ContentfulSynchronizer(client: client, persistenceStore: store)

sync.mapAssets(to: Asset.self)
sync.mapSpaces(to: SyncInfo.self)

sync.map(contentTypeId: "1kUEViTN4EmGiEaaeC6ouY", to: Author.self)
sync.map(contentTypeId: "5KMiN6YPvi42icqAUQMCQe", to: Category.self)
sync.map(contentTypeId: "2wKn6yEnZewu2SCCkus4as", to: Post.self)
```

ContentfulPersistence supports different persistence stores, this is an example of how to initialize it for use with Core Data:

```swift
let store = CoreDataStore(context: self.managedObjectContext)
```

The mapping to your data model will be derived automatically, but you can also customize it, browse the full documentation [on CocoaDocs][3].

## Documentation

For further information, check out the [Developer Documentation][4] or browse the [API documentation][3]. The latter can also be loaded into Xcode as a Docset.

## Installation

### CocoaPods

[CocoaPods][5] is the dependency manager for Objective-C and Swift, which automates and simplifies the process of using 3rd-party libraries like the ContentfulPersistence in your projects.

```ruby
platform :ios, '8.0'
use_frameworks!

target :MyApp do
	pod 'ContentfulPersistenceSwift'
end
```

## Unit Tests

To run the tests, do the following steps:

    $ make setup
    $ make test

or run them directly from Xcode.

## License

Copyright (c) 2016 Contentful GmbH. See LICENSE for further details.

[1]: https://www.contentful.com
[2]: https://github.com/contentful/contentful.swift
[3]: http://cocoadocs.org/docsets/ContentfulPersistenceSwift/
[4]: http://docs.contentfulcda.apiary.io/
[5]: https://cocoapods.org/
