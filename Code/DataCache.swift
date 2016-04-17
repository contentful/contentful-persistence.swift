//
//  DataCache.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 15/04/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

import Foundation

class DataCache {
    private let assetCache = NSCache()
    private let entryCache = NSCache()

    init(persistenceStore: PersistenceStore, assetType: Asset.Type, entryTypes: [Resource.Type]) {
        let truePredicate = NSPredicate(value: true)

        let assets: [Asset]? = try? persistenceStore.fetchAll(assetType, predicate: truePredicate)
        assets?.forEach { self.dynamicType.cacheResource(in: assetCache, resource: $0) }

        entryTypes.forEach {
            let entries: [Resource]? = try? persistenceStore.fetchAll($0, predicate: truePredicate)
            entries?.forEach { self.dynamicType.cacheResource(in: entryCache, resource: $0) }
        }
    }

    func assetForIdentifier(identifier: String) -> Asset? {
        return assetCache.objectForKey(identifier) as? Asset
    }

    func entryForIdentifier(identifier: String) -> Resource? {
        return entryCache.objectForKey(identifier) as? Resource
    }

    private static func cacheResource(in cache: NSCache, resource: Resource) {
        if let id = resource.identifier, resource = resource as? AnyObject {
            cache.setObject(resource, forKey: id)
        }
    }
}
