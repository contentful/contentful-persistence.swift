//
//  DataCache.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 15/04/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

import Foundation
import Contentful

typealias CacheKey = String

protocol DataCacheProtocol {
    init(persistenceStore: PersistenceStore, assetType: AssetPersistable.Type, entryTypes: [EntryPersistable.Type])

    func entry(for cacheKey: CacheKey) -> EntryPersistable?
    func item(for cacheKey: CacheKey) -> NSObject?
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

    fileprivate func itemsOf(_ types: [ContentSysPersistable.Type], cacheKey: CacheKey) -> EntryPersistable? {
        let predicate = ContentfulPersistence.predicate(for: identifier)

        let items: [EntryPersistable] = types.compactMap {
            if let result = try? store.fetchAll(type: $0, predicate: predicate) as [EntryPersistable] {
                return result.first
            }
            return nil
        }

        return items.first
    }

    func entry(for cacheKey: CacheKey) -> EntryPersistable? {
        return itemsOf(entryTypes, cacheKey: cacheKey)
    }

    func item(for cacheKey: CacheKey) -> NSObject? {
        return itemsOf([assetType] + entryTypes, cacheKey: cacheKey)
    }
}


/// Implemented using `NSCache`
class DataCache: DataCacheProtocol {

    public static func cacheKey(for resource: ContentSysPersistable) -> CacheKey {
        let localeCode = resource.localeCode ?? ""
        let cacheKey =  resource.id + "_" + localeCode
        return cacheKey
    }

    public static func cacheKey(for resource: LocalizableResource) -> CacheKey {
        let cacheKey =  resource.id + "_" + resource.currentlySelectedLocale.code
        return cacheKey
    }
    
    public static func cacheKey(for identifier: String, localeCode: String?) -> CacheKey {
        let cacheKey = identifier + "_" + (localeCode ?? "")
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

    func asset(for cacheKey: CacheKey) -> AssetPersistable? {
        return assetCache.object(forKey: cacheKey as AnyObject) as? AssetPersistable
    }

    func entry(for cacheKey: CacheKey) -> EntryPersistable? {
        return entryCache.object(forKey: cacheKey as AnyObject) as? EntryPersistable
    }

    func item(for cacheKey: CacheKey) -> NSObject? {
        var target = self.asset(for: identifier)

        if target == nil {
            target = self.entry(for: identifier)
        }

        return target
    }

    fileprivate static func cacheResource(in cache: NSCache<AnyObject, AnyObject>, resource: ContentSysPersistable) {
        let cacheKey = DataCache.cacheKey(for: resource)
        cache.setObject(resource as AnyObject, forKey: cacheKey as AnyObject)
    }
}
