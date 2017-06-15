//
//  SynchronizationManager.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 30/03/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

import Contentful
import Interstellar

func predicate(for id: String) -> NSPredicate {
    return NSPredicate(format: "id == %@", id)
}

/// Provides the ability to sync content from Contentful to a persistence store.
public class SynchronizationManager: PersistenceDelegate {

    /**
     Instantiate a new SynchronizationManager.

     - parameter persistenceStore: The persistence store to use for storage
     - parameter matching:         An optional query for syncing specific content,
     see <https://www.contentful.com/developers/docs/references/content-delivery-api/#/
     reference/synchronization/initial-synchronisation-of-entries-of-a-specific-content-type>

     - returns: An initialised instance of SynchronizationManager
     */
    public init(persistenceStore: PersistenceStore, persistenceModel: PersistenceModel) {
        self.persistentStore = persistenceStore
        self.persistenceModel = persistenceModel
    }

    fileprivate let persistenceModel: PersistenceModel

    public let persistentStore: PersistenceStore

    var syncToken: String? {
        return fetchSpace().syncToken
    }

    // MARK: - Helpers

    fileprivate func fetchSpace() -> SyncSpacePersistable {
        let createNewPersistentSpace: () -> (SyncSpacePersistable) = {
            let spacePersistable: SyncSpacePersistable = try! self.persistentStore.create(type: self.persistenceModel.spaceType)
            return spacePersistable
        }

        guard let fetchedResults = try? persistentStore.fetchAll(type: persistenceModel.spaceType, predicate: NSPredicate(value: true)) as [SyncSpacePersistable] else {
            return createNewPersistentSpace()
        }

        assert(fetchedResults.count <= 1)

        guard let space = fetchedResults.first else {
            return createNewPersistentSpace()
        }

        return space
    }

    public func create(syncSpace: SyncSpace) {
        let space = fetchSpace()
        space.syncToken = syncSpace.syncToken
    }

    // KEEP!
    public func resolveRelationships() {

        let cache = DataCache(persistenceStore: persistentStore, assetType: persistenceModel.assetType, entryTypes: persistenceModel.entryTypes)

        for (entryId, field) in relationshipsToResolve {
            if let entry = cache.entry(for: entryId) as? NSObject {

                for (fieldName, relatedEntryId) in field {
                    if let identifier = relatedEntryId as? String {
                        entry.setValue(cache.item(for: identifier), forKey: fieldName)
                    }

                    if let identifiers = relatedEntryId as? [String] {
                        let targets = identifiers.flatMap { id in
                            return cache.item(for: id)
                        }
                        entry.setValue(NSOrderedSet(array: targets), forKey: fieldName)
                    }
                }
            }
        }
        relationshipsToResolve.removeAll()
    }

    // MARK: - PersistenceDelegate

    /**
     This function is public as a side-effect of implementing `PersistenceDelegate`.

     - parameter asset: The newly created Asset
     */
    public func create(asset: Asset) {
        let type = persistenceModel.assetType
        let fetched: [AssetPersistable]? = try? persistentStore.fetchAll(type: type, predicate: predicate(for: asset.id))
        let persistable: AssetPersistable

        if let fetched = fetched?.first {
            persistable = fetched
        } else {
            persistable = try! persistentStore.create(type: type)
            persistable.id = asset.id
        }

        // Populate persistable with sys and fields data from the `Asset`
        persistable.updatedAt = asset.sys.updatedAt
        persistable.createdAt = asset.sys.updatedAt
        update(assetPersistable: persistable, of: type, with: asset)
    }


    /** Never call this directly.
     This function is public as a side-effect of implementing `SyncSpaceDelegate`.

     - parameter entry: The newly created Entry
     */
    public func create(entry: Entry) {

        guard let contentTypeId = entry.sys.contentTypeId, let type = persistenceModel.entryTypes.filter({ $0.contentTypeId == contentTypeId }).first else {
            return
        }
        let fetched: [EntryPersistable]? = try? persistentStore.fetchAll(type: type, predicate: predicate(for: entry.id))
        let persistable: EntryPersistable

        if let fetched = fetched?.first {
            persistable = fetched
        } else {
            persistable = try! persistentStore.create(type: type)
            persistable.id = entry.id
        }

        // Populate persistable with sys and fields data from the `Entry`
        persistable.updatedAt = entry.sys.updatedAt
        persistable.createdAt = entry.sys.updatedAt
        updateFields(for: persistable, of: type, with: entry)

        // TODO: Refactor relationships in the same way.
        // Now cache all the relationships.

        // ContentTypeId to either a single entry id or an array of entry id's to be linked.
        var relationships = [ContentTypeId: Any]()

        // Get fieldNames which are links/relationships/references to other types.
        if let relationshipNames = try? persistentStore.relationships(for: type) {

            for relationshipName in relationshipNames {

                if let linkedValue = entry.fields[relationshipName] {
                    if let targets = linkedValue as? [Link] {
                        // One-to-many.
                        relationships[relationshipName] = targets.map { $0.id }
                    } else {
                        // One-to-one.
                        assert(linkedValue is Link)
                        relationships[relationshipName] = (linkedValue as! Link).id
                    }
                }
            }
        }
        // Dictionary mapping Entry identifier's to a dictionary with fieldName to related entry id's.
        relationshipsToResolve[entry.id] = relationships
    }

    /**
     This function is public as a side-effect of implementing `PersistenceDelegate`.

     - parameter assetId: The ID of the deleted Asset
     */
    public func delete(assetWithId: String) {
        _ = try? persistentStore.delete(type: persistenceModel.assetType, predicate: predicate(for: assetWithId))
    }

    /**
     This function is public as a side-effect of implementing `SyncSpaceDelegate`.

     - parameter entryId: The ID of the deleted Entry
     */
    public func delete(entryWithId: String) {
        let predicate = ContentfulPersistence.predicate(for: entryWithId)

        for type in persistenceModel.entryTypes {
            _ = try? self.persistentStore.delete(type: type, predicate: predicate)
        }
    }

    // MARK: Private

    // MARK: Entry mapping

    // Dictionary mapping Entry identifier's to a dictionary with fieldName to related entry id's.
    fileprivate var relationshipsToResolve = [String: [FieldName: Any]]()

    // Dictionary to cache mappings for fields on `Entry` to `EntryPersistable` properties for each content type.
    fileprivate var sharedEntryPropertyNames: [ContentTypeId: [FieldName: String]] = [ContentTypeId: [FieldName: String]]()

    fileprivate func derivedMapping(for entryType: EntryPersistable.Type, and fields: [FieldName: Any]) -> [FieldName: String] {
        if let sharedPropertyNames = sharedEntryPropertyNames[entryType.contentTypeId] {
            return sharedPropertyNames
        }

        let persistablePropertyNames = Set(try! persistentStore.properties(for: entryType))
        let entryFieldNames = Set(fields.keys)
        let sharedPropertyNames = Array(persistablePropertyNames.intersection(entryFieldNames))

        let mapping = [FieldName: String](elements: sharedPropertyNames.map({ ($0, $0) }))

        // Cache.
        sharedEntryPropertyNames[entryType.contentTypeId] = mapping
        return mapping
    }

    fileprivate func updateFields(for entryPersistable: EntryPersistable, of type: EntryPersistable.Type, with entry: Entry) {

        // Key-Value Coding only works with NSObject types as it's an Obj-C API.
        guard let persistable = entryPersistable as? NSObject else { return }

        let mapping = type.mapping() ?? derivedMapping(for: type, and: entry.fields)

        for (fieldName, propertyName) in mapping {
            var fieldValue = entry.fields[fieldName]

            // handle symbol arrays
            if let array = fieldValue as? [Any] {
                fieldValue = NSKeyedArchiver.archivedData(withRootObject: array)
            }
            persistable.setValue(fieldValue, forKey: propertyName)
        }
    }

    // MARK: Asset mapping

    fileprivate var sharedAssetPropertyNames: [FieldName]?

    fileprivate func sharedAssetPropertyNames(for assetType: ContentPersistable.Type, asset: Asset) -> [FieldName] {

        if let sharedAssetPropertyNames = sharedAssetPropertyNames {
            return sharedAssetPropertyNames
        }

        let persistablePropertyNames = Set(try! persistentStore.properties(for: assetType))
        let sharedPropertyNames = Array(persistablePropertyNames.intersection(Set(["urlString", "title", "description"])))

        sharedAssetPropertyNames = sharedPropertyNames
        return sharedPropertyNames
    }

    fileprivate func update(assetPersistable: ContentPersistable, of type: ContentPersistable.Type, with asset: Asset) {
        // KVC only works with NSObject types.
        guard let persistable = assetPersistable as? NSObject else { return }

        let sharedPropertyNames = sharedAssetPropertyNames(for: type, asset: asset)

        // `Asset`s always have same properties.
        if sharedPropertyNames.contains("urlString") {
            persistable.setValue(asset.urlString, forKey: "urlString")
        }

        if sharedPropertyNames.contains("title") {
            persistable.setValue(asset.title, forKey: "title")
        }

        // FIXME: "description" is broken.
        if sharedPropertyNames.contains("description") {
            persistable.setValue(asset.description, forKey: "description")
        }
    }
}

extension Dictionary {

    init(elements: [(Key, Value)]) {
        self.init()
        for (key, value) in elements {
            updateValue(value, forKey: key)
        }
    }
}
