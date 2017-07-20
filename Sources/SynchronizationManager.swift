//
//  SynchronizationManager.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 30/03/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

import CoreData
import Contentful
import Interstellar

func predicate(for id: String) -> NSPredicate {
    return NSPredicate(format: "id == %@", id)
}

fileprivate struct DeletedRelationship {}

/// Provides the ability to sync content from Contentful to a persistence store.
public class SynchronizationManager: PersistenceIntegration {

    // MARK: Integration

    public let name: String = "ContentfulPersistence"

    public var version: String {
        guard
            let bundleInfo = Bundle(for: Client.self).infoDictionary,
            let versionNumberString = bundleInfo["CFBundleShortVersionString"] as? String
            else { return "Unknown" }

        return versionNumberString
    }

    /**
     Instantiate a new SynchronizationManager.

     - parameter persistenceStore: The persistence store to use for storage
     - parameter matching:         An optional query for syncing specific content,
     see <https://www.contentful.com/developers/docs/references/content-delivery-api/#/
     reference/synchronization/initial-synchronisation-of-entries-of-a-specific-content-type>

     - returns: An initialised instance of SynchronizationManager
     */
    public init(spaceId: String? = nil,
                accessToken: String? = nil,
                clientConfiguration: ClientConfiguration = .default,
                sessionConfiguration: URLSessionConfiguration = .default,
                persistenceStore: PersistenceStore,
                persistenceModel: PersistenceModel) {
        self.persistentStore = persistenceStore
        self.persistenceModel = persistenceModel
        guard let spaceId = spaceId, let accessToken = accessToken else {
            return }

        self.client = Client(spaceId: spaceId,
                            accessToken: accessToken,
                            clientConfiguration: clientConfiguration,
                            sessionConfiguration: sessionConfiguration,
                            persistenceIntegration: self)
    }

    // TODO: SyncSpace being passed back has the most recent diffs so that you can delete stuff from secondary cache.
    public func sync(then completion: @escaping ResultsHandler<SyncSpace>) {

        let safeCompletion: ResultsHandler<SyncSpace> = { result in
            self.persistentStore.performBlock {
                completion(result)
            }
        }

        if let syncToken = self.syncToken {
            client?.nextSync(for: SyncSpace(syncToken: syncToken), completion: safeCompletion)
        } else {
            client?.initialSync(completion: safeCompletion)
        }
    }

    public var client: Client?

    fileprivate let persistenceModel: PersistenceModel

    fileprivate let persistentStore: PersistenceStore

    public var syncToken: String? {
        var syncToken: String? = nil
        persistentStore.performAndWait {
            syncToken = self.fetchSpace().syncToken
        }
        return syncToken
    }

    public func update(with syncSpace: SyncSpace) {
        persistentStore.performBlock {
            for asset in syncSpace.assets {
                self.create(asset: asset)
            }

            // Update and deduplicate all entries.
            for entry in syncSpace.entries {
                self.create(entry: entry)
            }

            for deletedAssetId in syncSpace.deletedAssetIds {
                self.delete(assetWithId: deletedAssetId)
            }

            for deletedEntryId in syncSpace.deletedEntryIds {
                self.delete(entryWithId: deletedEntryId)
            }

            self.update(syncToken: syncSpace.syncToken)
            self.resolveRelationships()
            self.save()
        }
    }

    public func update(syncToken: String) {
        let space = self.fetchSpace()
        space.syncToken = syncToken
    }

    public func resolveRelationships() {

        let cache = DataCache(persistenceStore: self.persistentStore,
                              assetType: self.persistenceModel.assetType,
                              entryTypes: self.persistenceModel.entryTypes)

        for (entryId, fields) in self.relationshipsToResolve {
            if let entryPersistable = cache.entry(for: entryId) as? NSObject {

                for (fieldName, relatedEntryId) in fields {
                    if let identifier = relatedEntryId as? String {
                        entryPersistable.setValue(cache.item(for: identifier), forKey: fieldName)
                    }

                    if let identifiers = relatedEntryId as? [String] {
                        let targets = identifiers.flatMap { id in
                            return cache.item(for: id)
                        }
                        entryPersistable.setValue(NSOrderedSet(array: targets), forKey: fieldName)
                    }
                    // Nullfiy the link if it's nil.
                    if relatedEntryId is DeletedRelationship {
                        entryPersistable.setValue(nil, forKey: fieldName)
                    }
                }
            }
        }
        self.relationshipsToResolve.removeAll()
    }

    // MARK: - PersistenceDelegate

    /**
     This function is public as a side-effect of implementing `PersistenceDelegate`.

     - parameter asset: The newly created Asset
     */
    public func create(asset: Asset) {
        let type = persistenceModel.assetType

        let fetched: [AssetPersistable]? = try? self.persistentStore.fetchAll(type: type, predicate: predicate(for: asset.id))
        let persistable: AssetPersistable

        if let fetched = fetched?.first {
            persistable = fetched
        } else {
            do {
                persistable = try self.persistentStore.create(type: type)
                persistable.id = asset.id
            } catch let error {
                fatalError("Could not create the Asset persistent store\n \(error)")
            }
        }

        // Populate persistable with sys and fields data from the `Asset`
        persistable.title               = asset.title
        persistable.updatedAt           = asset.sys.updatedAt
        persistable.createdAt           = asset.sys.updatedAt
        persistable.urlString           = asset.urlString
        persistable.assetDescription    = asset.description
    }


    /** Never call this directly.
     This function is public as a side-effect of implementing `SyncSpaceDelegate`.

     - parameter entry: The newly created Entry
     */
    public func create(entry: Entry) {

        guard let contentTypeId = entry.sys.contentTypeId else { return }
        guard let type = persistenceModel.entryTypes.filter({ $0.contentTypeId == contentTypeId }).first else { return }

        let fetched: [EntryPersistable]? = try? self.persistentStore.fetchAll(type: type, predicate: predicate(for: entry.id))
        let persistable: EntryPersistable

        if let fetched = fetched?.first {
            persistable = fetched
        } else {
            do {
                persistable = try self.persistentStore.create(type: type)
                persistable.id = entry.id
                persistable.createdAt = entry.sys.createdAt
            } catch let error {
                fatalError("Could not create the Entry persistent store\n \(error)")
            }
        }

        // Populate persistable with sys and fields data from the `Entry`
        persistable.updatedAt = entry.sys.updatedAt

        self.updatePropertyFields(for: persistable, of: type, with: entry)
        self.relationshipsToResolve[entry.id] = self.persistableRelationships(for: persistable, of: type, with: entry)
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

    public func save() {
        do {
            try persistentStore.save()
        } catch let error {
            assertionFailure("Could not save the persistent store\n \(error)")
        }
    }


    // MARK: Private

    // Dictionary mapping Entry identifier's to a dictionary with fieldName to related entry id's.
    fileprivate var relationshipsToResolve = [String: [FieldName: Any]]()

    // Dictionary to cache mappings for fields on `Entry` to `EntryPersistable` properties for each content type.
    fileprivate var sharedEntryPropertyNames: [ContentTypeId: [FieldName: String]] = [ContentTypeId: [FieldName: String]]()

    fileprivate var sharedRelationshipPropertyNames: [ContentTypeId: [FieldName: String]] = [ContentTypeId: [FieldName: String]]()

    // Returns regular (non-relationship) field to property mappings.
    internal func propertyMapping(for entryType: EntryPersistable.Type, and fields: [FieldName: Any]) -> [FieldName: String] {
        // Filter out user-defined properties that represent relationships.
        guard let persistentRelationshipPropertyNames = try? persistentStore.relationships(for: entryType) else {
            assertionFailure("Could not filter out user-defined properties that represent relationships.")
            return [:]
        }

        if let sharedPropertyNames = sharedEntryPropertyNames[entryType.contentTypeId] {
            return sharedPropertyNames
        }

        // If user-defined relationship properties exist, use them, but filter out relationships.
        let mapping = entryType.fieldMapping()

        let relationshipPropertyNamesToExclude = Set(persistentRelationshipPropertyNames).intersection(Set(mapping.values))
        let filteredMappingTuplesArray = mapping.filter { (_, propertyName) -> Bool in
            return relationshipPropertyNamesToExclude.contains(propertyName) == false
        }
        let filteredMapping = Dictionary(elements: filteredMappingTuplesArray)

        // Cache.
        sharedEntryPropertyNames[entryType.contentTypeId] = filteredMapping
        return filteredMapping
    }

    internal func relationshipMapping(for entryType: EntryPersistable.Type, and fields: [FieldName: Any]) -> [FieldName: String] {
        // Filter out user-defined regular fields that do NOT represent relationships.
        guard let persistentPropertyNames = try? persistentStore.properties(for: entryType) else {
            assertionFailure("Could not filter out user-defined regular fields that do NOT represent relationships.")
            return [:]
        }

        if let sharedPropertyNames = sharedRelationshipPropertyNames[entryType.contentTypeId] {
            return sharedPropertyNames
        }

        let mapping = entryType.fieldMapping()
        // Filter out user-defined regular fields that do NOT represent relationships.
        let persistentPropertyNames = try! persistentStore.properties(for: entryType)
        let propertyNamesToExclude = Set(persistentPropertyNames).intersection(Set(mapping.values))

        let filteredMappingTuplesArray = mapping.filter { (_, propertyName) -> Bool in
            return propertyNamesToExclude.contains(propertyName) == false
        }
        let filteredMapping = Dictionary(elements: filteredMappingTuplesArray)

        // Cache.
        sharedRelationshipPropertyNames[entryType.contentTypeId] = filteredMapping
        return filteredMapping
    }

    fileprivate func updatePropertyFields(for entryPersistable: EntryPersistable, of type: EntryPersistable.Type, with entry: Entry) {

        // Key-Value Coding only works with NSObject types as it's an Obj-C API.
        guard let persistable = entryPersistable as? NSManagedObject else { return }

        let mapping = propertyMapping(for: type, and: entry.fields)

        for (fieldName, propertyName) in mapping {
            var fieldValue = entry.fields[fieldName]

            // handle symbol arrays
            if let array = fieldValue as? [Any] {
                fieldValue = NSKeyedArchiver.archivedData(withRootObject: array)
            }
            persistable.setValue(fieldValue, forKey: propertyName)
        }
    }

    fileprivate func persistableRelationships(for entryPersistable: EntryPersistable,
                                              of type: EntryPersistable.Type,
                                              with entry: Entry) -> [FieldName: Any] {
        // FieldName to either a single entry id or an array of entry id's to be linked.
        var relationships = [FieldName: Any]()

        let relationshipMapping = self.relationshipMapping(for: type, and: entry.fields)
        let relationshipFieldNames = Array(relationshipMapping.keys)

        // Get fieldNames which are links/relationships/references to other types.
        for relationshipName in relationshipFieldNames {
            guard let propertyName = relationshipMapping[relationshipName] else { continue }

            // Get the name of the propery to be linked to.
            if let linkedValue = entry.fields[relationshipName] {
                if let targets = linkedValue as? [Link] {
                    // One-to-many.
                    relationships[propertyName] = targets.map { $0.id }
                } else {
                    // One-to-one.
                    assert(linkedValue is Link)
                    relationships[propertyName] = (linkedValue as! Link).id
                }
            } else if entry.fields[relationshipName] == nil {
                relationships[propertyName] = DeletedRelationship()
            }
        }

        return relationships
    }

    fileprivate func fetchSpace() -> SyncSpacePersistable {
        let createNewPersistentSpace: () -> (SyncSpacePersistable) = {
            do {
                let spacePersistable: SyncSpacePersistable = try self.persistentStore.create(type: self.persistenceModel.spaceType)
                return spacePersistable
            } catch let error {
                fatalError("Could not create the Sync Space persistent store\n \(error)")
            }
        }

        guard let fetchedResults = try? persistentStore.fetchAll(type: persistenceModel.spaceType,
                                                                 predicate: NSPredicate(value: true)) as [SyncSpacePersistable] else {
            return createNewPersistentSpace()
        }

        assert(fetchedResults.count <= 1)

        guard let space = fetchedResults.first else {
            return createNewPersistentSpace()
        }

        return space
    }
}

extension Dictionary {

    // Helper initializer to allow declarative style Dictionary initialization using an array of tuples.
    init(elements: [(Key, Value)]) {
        self.init()
        for (key, value) in elements {
            updateValue(value, forKey: key)
        }
    }
}
