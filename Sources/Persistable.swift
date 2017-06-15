//
//  Persistable.swift
//  ContentfulPersistence
//
//  Created by JP Wright on 15.06.17.
//  Copyright © 2017 Contentful GmbH. All rights reserved.
//

import Foundation
import Contentful

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

// Protocols are marked with @objc attribute for two reasons:
// 1) CoreData requires that model classes inherit from `NSManagedObject`
// 2) @objc enables optional protocol methods that don't require implementation.
public protocol ContentPersistable: class {
    var id: String? { get set }

    var updatedAt: Date? { get set }

    var createdAt: Date? { get set }
}

public protocol SyncSpacePersistable: class {
    /// The current synchronization token
    var syncToken: String? { get set }
}

public protocol AssetPersistable: ContentPersistable {
    /// URL of the Asset.
    var urlString: String? { get set }

    /// The title of the Asset.
    var title: String? { get set }

    /// The description of the asset. Named `assetDescription` to avoid clashing with `description`
    /// property that all NSObject's have.
    var assetDescription: String? { get set }
}


public protocol EntryPersistable: ContentPersistable {
    /// The identifier of the Contentful content type that will map to this type of `EntryPersistable`
    static var contentTypeId: ContentTypeId { get }

    /// This method has a defualt implementation that maps `Entry` fields to properties with the same name.
    /// Override this method to provide a custom mapping.
    static func mapping() -> [FieldName: String]?
}


public extension EntryPersistable {

    // TODO: Make it a mapping of FieldNames to Swift 4 keypaths!
    static func mapping() -> [FieldName: String]? {
        return nil
    }
}
