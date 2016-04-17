//
//  ContentfulSynchronizer.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 30/03/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

import Contentful
import Interstellar

public class ContentfulSynchronizer: SyncSpaceDelegate {
    private let client: Client
    private let matching: [String: AnyObject]
    private let store: PersistenceStore

    private var mappingForEntries = [String: [String: String]]()
    private var mappingForAssets: [String: String]!

    private var typeForAssets: Asset.Type!
    private var typeForEntries = [String: Resource.Type]()
    private var typeForSpaces: Space.Type!

    private var relationshipsToResolve = [String: [String: Any]]()

    var syncToken: String? {
        return fetchSpace().syncToken
    }

    public init(client: Client, persistenceStore: PersistenceStore, matching: [String: AnyObject] = [String: AnyObject]()) {
        self.client = client
        self.matching = matching
        self.store = persistenceStore
    }

    public func map(contentTypeId contentTypeId: String, to type: Resource.Type, propertyMapping: [String:String]? = nil) {
        mappingForEntries[contentTypeId] = propertyMapping
        typeForEntries[contentTypeId] = type
    }

    public func mapAssets(to type: Asset.Type, propertyMapping: [String:String]? = nil) {
        mappingForAssets = propertyMapping
        typeForAssets = type
    }

    public func mapSpaces(to type: Space.Type) {
        typeForSpaces = type
    }

    public func sync(completion: (Bool) -> ()) {
        assert(typeForAssets != nil, "Define a type for Assets using mapAssets(to:)")
        assert(typeForEntries.first?.1 != nil, "Define a type for Entries using map(contentTypeId:to:)")
        assert(typeForSpaces != nil, "Define a type for Spaces using mapSpaces(to:)")

        let initial: Bool
        let signal: Signal<SyncSpace>

        if let syncToken = syncToken {
            initial = false
            let space = SyncSpace(client: client, syncToken: syncToken, delegate: self)
            signal = space.sync(matching).1
        } else {
            initial = true
            signal = client.initialSync(matching).1
        }

        relationshipsToResolve.removeAll()

        signal
        .next {
            var space = self.fetchSpace()
            space.syncToken = $0.syncToken

            if initial {
                $0.assets.forEach { self.createAsset($0) }
                $0.entries.forEach { self.createEntry($0) }
            }

            self.resolveRelationships()

            _ = try? self.store.save()
            completion(true)
        }
        .error {
            NSLog("Error: \($0)")
            completion(false)
        }
    }

    // MARK: - Helpers

    private func create(identifier: String, fields: [String: Any], type: Resource.Type, mapping: [String: String]) {
        assert(mapping.count > 0, "Empty mapping for \(type)")

        let predicate = self.dynamicType.predicateForIdentifier(identifier)
        let fetched: [Resource]? = try? store.fetchAll(type, predicate: predicate)
        let persisted: Resource

        if let fetched = fetched?.first {
            persisted = fetched
        } else {
            persisted = try! store.create(type)
            persisted.identifier = identifier
        }

        if let persisted = persisted as? NSObject {
            map(fields, to: persisted, mapping: mapping)
        }
    }

    private func deriveMapping(fields: [String], type: Resource.Type, prefix: String = "") -> [String: String] {
        var result = [String: String]()
        let properties = (try! store.propertiesFor(type: type)).filter { fields.contains($0) }
        properties.forEach { result["\(prefix)\($0)"] = $0 }
        return result
    }

    private func fetchSpace() -> Space {
        let result: [Space]? = try? self.store.fetchAll(self.typeForSpaces, predicate: NSPredicate(value: true))

        guard let space = result?.first else {
            return try! self.store.create(self.typeForSpaces)
        }

        assert(result?.count == 1)
        return space
    }

    private func map(fields: [String: Any], to: NSObject, mapping: [String: String]) {
        mapping.forEach {
            let key = $0.1
            var value = valueFor(fields, keyPath: $0.0)

            // such case, much special, wow
            if let string = value as? String where string.hasPrefix("//") && key == "url" {
                value = "https:\(string)"
            }

            // handle symbol arrays
            if let array = value as? NSArray {
                value = NSKeyedArchiver.archivedDataWithRootObject(array)
            }

            to.setValue(value as? NSObject, forKeyPath: key)
        }
    }

    private static func predicateForIdentifier(identifier: String) -> NSPredicate {
        return NSPredicate(format: "identifier == '%@'", identifier)
    }

    private func resolveRelationships() {
        let entryTypes = typeForEntries.map { $0.1 }
        let cache = DataCache(persistenceStore: store, assetType: typeForAssets, entryTypes: entryTypes)

        relationshipsToResolve.forEach {
            if let entry = cache.entryForIdentifier($0.0) as? NSObject {
                $0.1.forEach {
                    if let identifier = $0.1 as? String {
                        entry.setValue(cache.itemForIdentifier(identifier), forKey: $0.0)
                    }

                    if let identifiers = $0.1 as? [String] {
                        let targets = identifiers.flatMap { return cache.itemForIdentifier($0) }
                        entry.setValue(NSOrderedSet(array: targets), forKey: $0.0)
                    }
                }
            }
        }
    }

    // MARK: - SyncSpaceDelegate

    public func createAsset(asset: Contentful.Asset) {
        if mappingForAssets == nil {
            mappingForAssets = deriveMapping(Array(asset.fields.keys), type: typeForAssets)

            ["file", "file.details.image"].forEach {
                if let fileFields = valueFor(asset.fields, keyPath: $0) as? [String: AnyObject] {
                    mappingForAssets! += deriveMapping(Array(fileFields.keys), type: typeForAssets, prefix: "\($0).")
                }
            }
        }

        create(asset.identifier, fields: asset.fields, type: typeForAssets, mapping: mappingForAssets)
    }

    private func getIdentifier(target: Any) -> String? {
        if let target = target as? Contentful.Asset {
            return target.identifier
        }

        if let target = target as? Entry {
            return target.identifier
        }

        return nil
    }

    public func createEntry(entry: Entry) {
        let contentTypeId = ((entry.sys["contentType"] as? [String: AnyObject])?["sys"] as? [String: AnyObject])?["id"] as? String

        if let contentTypeId = contentTypeId, type = typeForEntries[contentTypeId] {
            var mapping = mappingForEntries[contentTypeId]
            if mapping == nil {
                mapping = deriveMapping(Array(entry.fields.keys), type: type)
            }

            create(entry.identifier, fields: entry.fields, type: type, mapping: mapping!)

            var relationships = [String: Any]()

            _ = try? store.relationshipsFor(type: type).forEach {
                let target = entry.fields[$0]

                if let targets = target as? [Any] {
                    relationships[$0] = targets.flatMap { self.getIdentifier($0) }
                } else {
                    relationships[$0] = getIdentifier(target)
                }
            }

            relationshipsToResolve[entry.identifier] = relationships
        }
    }

    public func deleteAsset(assetId: String) {
        let predicate = self.dynamicType.predicateForIdentifier(assetId)
        _ = try? store.delete(typeForAssets, predicate: predicate)
    }

    public func deleteEntry(entryId: String) {
        let predicate = self.dynamicType.predicateForIdentifier(entryId)

        typeForEntries.forEach {
            _ = try? self.store.delete($0.1, predicate: predicate)
        }
    }
}
