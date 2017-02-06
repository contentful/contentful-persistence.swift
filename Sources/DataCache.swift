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

    func entry(for identifier: String) -> Resource?
    func item (for identifier: String) -> NSObject?
}

/// Does not actually cache anything, but directly uses the persistence store instead
class NoDataCache: DataCacheProtocol {
    fileprivate let assetType: Asset.Type
    fileprivate let entryTypes: [Resource.Type]
    fileprivate let store: PersistenceStore

    required init(persistenceStore: PersistenceStore, assetType: Asset.Type, entryTypes: [Resource.Type]) {
        self.assetType = assetType
        self.entryTypes = entryTypes
        self.store = persistenceStore
    }

    fileprivate func itemsOf(_ types: [Resource.Type], identifier: String) -> Resource? {
        let predicate = ContentfulPersistence.predicate(for: identifier)

        let items: [Resource] = types.flatMap {
            if let result = try? store.fetchAll(type: $0, predicate: predicate) as [Resource] {
                return result.first
            }
            return nil
        }

        return items.first
    }

    func entry(for identifier: String) -> Resource? {
        return itemsOf(entryTypes, identifier: identifier)
    }

    func item(for identifier: String) -> NSObject? {
        return itemsOf([assetType] + entryTypes, identifier: identifier) as? NSObject
    }
}

/// Implemented using `NSCache`
class DataCache: DataCacheProtocol {
    fileprivate let assetCache = NSCache<AnyObject, AnyObject>()
    fileprivate let entryCache = NSCache<AnyObject, AnyObject>()

    required init(persistenceStore: PersistenceStore, assetType: Asset.Type, entryTypes: [Resource.Type]) {
        let truePredicate = NSPredicate(value: true)

        let assets: [Asset]? = try? persistenceStore.fetchAll(type: assetType, predicate: truePredicate)
        assets?.forEach { type(of: self).cacheResource(in: assetCache, resource: $0) }

        entryTypes.forEach {
            let entries: [Resource]? = try? persistenceStore.fetchAll(type: $0, predicate: truePredicate)
            entries?.forEach { type(of: self).cacheResource(in: entryCache, resource: $0) }
        }
    }

    fileprivate func assetForIdentifier(_ identifier: String) -> Asset? {
        return assetCache.object(forKey: identifier as AnyObject) as? Asset
    }

    func entry(for identifier: String) -> Resource? {
        return entryCache.object(forKey: identifier as AnyObject) as? Resource
    }

    func item(for identifier: String) -> NSObject? {
        var target = self.assetForIdentifier(identifier) as? NSObject

        if target == nil {
            target = self.entry(for: identifier) as? NSObject
        }

        return target
    }

    fileprivate static func cacheResource(in cache: NSCache<AnyObject, AnyObject>, resource: Resource) {
        if let id = resource.identifier {
            cache.setObject(resource as AnyObject, forKey: id as AnyObject)
        }
    }
}
