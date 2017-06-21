//
//  Persistable.swift
//  ContentfulPersistence
//
//  Created by JP Wright on 15.06.17.
//  Copyright © 2017 Contentful GmbH. All rights reserved.
//

import Foundation
import Contentful

/**
 Structure used to define the schema of your CoreData model and it's correlation to your Content Model
 in Contentful. Pass in your `NSManagedObject` subclasses conforming to `SyncSpacePersistable`,
 `AssetPersistable` and `EntryPersistable` to properly map your content to CoreData entities.
 */
public struct PersistenceModel {
    public let spaceType: SyncSpacePersistable.Type
    public let assetType: AssetPersistable.Type
    public let entryTypes: [EntryPersistable.Type]

    public init(spaceType: SyncSpacePersistable.Type, assetType: AssetPersistable.Type, entryTypes: [EntryPersistable.Type]) {
        self.spaceType = spaceType
        self.assetType = assetType
        self.entryTypes = entryTypes
    }
}

/**
 Base protocol for all `AssetPersistable` and `EntryPersistable`.
 */
// Protocols are marked with @objc attribute for two reasons:
// 1) CoreData requires that model classes inherit from `NSManagedObject`
// 2) @objc enables optional protocol methods that don't require implementation.
public protocol ContentPersistable: class {
    /// The unique identifier of the Resource.
    var id: String { get set }

    /// The date representing the last time the Contentful Resource was updated.
    var updatedAt: Date? { get set }

    /// The date that the Contentful Resource was first created.
    var createdAt: Date? { get set }
}

/**
 Your `NSManagedObject` subclass should conform to this `SyncSpacePersistable` to enable continuing
 a sync from a sync token on subsequent launches of your application rather than re-fetching all data
 during an initialSync. See [Contentful's Content Delivery API docs](https://www.contentful.com/developers/docs/references/content-delivery-api/#/reference/synchronization/pagination-and-subsequent-syncs) 
 for more information.
 */
public protocol SyncSpacePersistable: class {
    /// The current synchronization token
    var syncToken: String? { get set }
}

/**
 Conform to `AssetPersistable` protocol to enable mapping of your Contentful media Assets to
 your `NSManagedObject` subclass.
 */
public protocol AssetPersistable: ContentPersistable {
    /// URL of the Asset.
    var urlString: String? { get set }

    /// The title of the Asset.
    var title: String? { get set }

    /// The description of the asset. Named `assetDescription` to avoid clashing with `description`
    /// property that all NSObject's have.
    var assetDescription: String? { get set }
}

/**
 Conform to `EntryPersistable` protocol to enable mapping of your Contentful content type to  
 your `NSManagedObject` subclass.
 */
public protocol EntryPersistable: ContentPersistable {
    /// The identifier of the Contentful content type that will map to this type of `EntryPersistable`
    static var contentTypeId: ContentTypeId { get }

    /// This method has a defualt implementation that maps `Entry` fields to properties with the same name.
    /// Override this method to provide a custom mapping. Note that after Swift 4 is release, this method will
    /// be deprecated in favor of leveraging the auto-synthesized `CodingKeys` enum that is generated for all
    /// types conforming to `Codable`.
    static func mapping() -> [FieldName: String]?
}

public extension EntryPersistable {

    // Default implementation returns `nil` so that the `SynchornizationManager` will infer the mapping instead.
    static func mapping() -> [FieldName: String]? {
        return nil
    }
}
