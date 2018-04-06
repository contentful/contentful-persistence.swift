//
//  DataCache.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 15/04/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

import Foundation
import Contentful

protocol DataCacheProtocol {
    init(persistenceStore: PersistenceStore, assetType: AssetPersistable.Type, entryTypes: [EntryPersistable.Type])

    func entry(for identifier: String) -> EntryPersistable?
    func item(for identifier: String) -> NSObject?
}

/// Does not actually cache anything, but directly uses the persistence store instead
class NoDataCache: DataCacheProtocol {
    fileprivate let assetType: AssetPersistable.Type
    fileprivate let entryTypes: [EntryPersistable.Type]
    fileprivate let store: PersistenceStore

    required init(persistenceStore: PersistenceStore, assetType: AssetPersistable.Type, entryTypes: [EntryPersistable.Type]) {
        self.assetType = assetType
        self.entryTypes = entryTypes
        self.store = persistenceStore
    }

    fileprivate func itemsOf(_ types: [ContentSysPersistable.Type], identifier: String) -> EntryPersistable? {
        let predicate = ContentfulPersistence.predicate(for: identifier)

        let items: [EntryPersistable] = types.compactMap {
            if let result = try? store.fetchAll(type: $0, predicate: predicate) as [EntryPersistable] {
                return result.first
            }
            return nil
        }

        return items.first
    }

    func entry(for identifier: String) -> EntryPersistable? {
        return itemsOf(entryTypes, identifier: identifier)
    }

    func item(for identifier: String) -> NSObject? {
        return itemsOf([assetType] + entryTypes, identifier: identifier) as? NSObject
    }
}


/// Implemented using `NSCache`
class DataCache: DataCacheProtocol {

    public static func cacheKey(for resource: ContentSysPersistable) -> String {
        let cacheKey =  resource.id + "_" + resource.localeCode
        return cacheKey
    }

    public static func cacheKey(for resource: LocalizableResource) -> String {
        let cacheKey =  resource.id + "_" + resource.currentlySelectedLocale.code
        return cacheKey
    }

    fileprivate let assetCache = NSCache<AnyObject, AnyObject>()
    fileprivate let entryCache = NSCache<AnyObject, AnyObject>()

    required init(persistenceStore: PersistenceStore, assetType: AssetPersistable.Type, entryTypes: [EntryPersistable.Type]) {
        let truePredicate = NSPredicate(value: true)

        let assets: [AssetPersistable]? = try? persistenceStore.fetchAll(type: assetType, predicate: truePredicate)
        assets?.forEach { type(of: self).cacheResource(in: assetCache, resource: $0) }

        for entryType in entryTypes {
            let entries: [EntryPersistable]? = try? persistenceStore.fetchAll(type: entryType, predicate: truePredicate)
            entries?.forEach { type(of: self).cacheResource(in: entryCache, resource: $0) }
        }
    }

    func asset(for identifier: String) -> AssetPersistable? {
        return assetCache.object(forKey: identifier as AnyObject) as? AssetPersistable
    }

    func entry(for identifier: String) -> EntryPersistable? {
        return entryCache.object(forKey: identifier as AnyObject) as? EntryPersistable
    }

    func item(for identifier: String) -> NSObject? {
        var target = self.asset(for: identifier) as? NSObject

        if target == nil {
            target = self.entry(for: identifier) as? NSObject
        }

        return target
    }

    fileprivate static func cacheResource(in cache: NSCache<AnyObject, AnyObject>, resource: ContentSysPersistable) {
        let cacheKey = DataCache.cacheKey(for: resource)
        cache.setObject(resource as AnyObject, forKey: cacheKey as AnyObject)
    }
}
