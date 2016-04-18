//
//  DataCache.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 15/04/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

import Foundation

protocol DataCacheProtocol {
    init(persistenceStore: PersistenceStore, assetType: Asset.Type, entryTypes: [Resource.Type])

    func entryForIdentifier(identifier: String) -> Resource?
    func itemForIdentifier(identifier: String) -> NSObject?
}

/// Does not actually cache anything, but directly uses the persistence store instead
class NoDataCache: DataCacheProtocol {
    private let assetType: Asset.Type
    private let entryTypes: [Resource.Type]
    private let store: PersistenceStore

    required init(persistenceStore: PersistenceStore, assetType: Asset.Type, entryTypes: [Resource.Type]) {
        self.assetType = assetType
        self.entryTypes = entryTypes
        self.store = persistenceStore
    }

    private func itemsOf(types: [Resource.Type], identifier: String) -> Resource? {
        let predicate = predicateForIdentifier(identifier)

        let items: [Resource] = types.flatMap {
            if let result = try? store.fetchAll($0, predicate: predicate) as [Resource] {
                return result.first
            }
            return nil
        }

        return items.first
    }

    func entryForIdentifier(identifier: String) -> Resource? {
        return itemsOf(entryTypes, identifier: identifier)
    }

    func itemForIdentifier(identifier: String) -> NSObject? {
        return itemsOf([assetType] + entryTypes, identifier: identifier) as? NSObject
    }
}

/// Implemented using `NSCache`
class DataCache: DataCacheProtocol {
    private let assetCache = NSCache()
    private let entryCache = NSCache()

    required init(persistenceStore: PersistenceStore, assetType: Asset.Type, entryTypes: [Resource.Type]) {
        let truePredicate = NSPredicate(value: true)

        let assets: [Asset]? = try? persistenceStore.fetchAll(assetType, predicate: truePredicate)
        assets?.forEach { self.dynamicType.cacheResource(in: assetCache, resource: $0) }

        entryTypes.forEach {
            let entries: [Resource]? = try? persistenceStore.fetchAll($0, predicate: truePredicate)
            entries?.forEach { self.dynamicType.cacheResource(in: entryCache, resource: $0) }
        }
    }

    private func assetForIdentifier(identifier: String) -> Asset? {
        return assetCache.objectForKey(identifier) as? Asset
    }

    func entryForIdentifier(identifier: String) -> Resource? {
        return entryCache.objectForKey(identifier) as? Resource
    }

    func itemForIdentifier(identifier: String) -> NSObject? {
        var target = self.assetForIdentifier(identifier) as? NSObject

        if target == nil {
            target = self.entryForIdentifier(identifier) as? NSObject
        }

        return target
    }

    private static func cacheResource(in cache: NSCache, resource: Resource) {
        if let id = resource.identifier, resource = resource as? AnyObject {
            cache.setObject(resource, forKey: id)
        }
    }
}
