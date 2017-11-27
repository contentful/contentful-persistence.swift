//
//  SynchronizationManager.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 30/03/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

import CoreData
import Contentful

func predicate(for id: String, localeCode: LocaleCode) -> NSPredicate {
    return NSPredicate(format: "id == %@ AND localeCode == %@", id, localeCode)
}

func predicate(for id: String) -> NSPredicate {
    return NSPredicate(format: "id == %@", id)
}

// A type used to cache relationships that should be deleted in the `resolveRelationships()` method
private struct DeletedRelationship {}

/**
 Configure your SynchronizationManager instance with a localization scheme to define which data should
 be saved to your persistent store. The `LocalizationScheme.default` scheme will save entities representing
 data only for the default locale of your space, while the `LocalizationScheme.all` will save data 
 for all locales.
 */
public enum LocalizationScheme {
    /// Use the `.default` scheme to save only for the default locale for your space.
    case `default`
    /** 
     Specify that data should be saved for only one locale using this scheme.
     For example the scheme, `LocalizationScheme.one("es-MX")`, will configure this library to only
     save data for Mexican Spanish. Not that an `assertionFailure` will be thrown if Mexican Spanish
     is not a valid locale on your space.
     */
    case one(LocaleCode)
    /** 
     Require that data for all locales be saved to your persistent store. Remember to specify a
     predicate that includes pattern matching for the `localeCode` property of your `Persistable` model classes
     when fetching from your local database.
    */
    case all
}

/// Provides the ability to sync content from Contentful to a persistence store.
public class SynchronizationManager: PersistenceIntegration {

    // MARK: Integration

    public let name: String = "ContentfulPersistence"

    public var version: String {
        guard
            let bundleInfo = Bundle(for: SynchronizationManager.self).infoDictionary,
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
    public init(client: Client? = nil,
                localizationScheme: LocalizationScheme,
                persistenceStore: PersistenceStore,
                persistenceModel: PersistenceModel) {

        self.persistentStore = persistenceStore
        self.persistenceModel = persistenceModel
        self.localizationScheme = localizationScheme
        self.localeCodes = []

        if let client = client {
            client.persistenceIntegration = self
            self.client = client
        }
    }

    fileprivate var localeCodes: [LocaleCode]

    public func update(localeCodes: [LocaleCode]) {
        switch localizationScheme {
        case .one(let localeCode):
            if localeCodes.contains(localeCode) == false {
                assertionFailure("LocaleCode that SynchronizationManager is configured"
                    + " to use does not correspond to any locales available for current Contentful.Space")
            }
        default: break
        }
        self.localeCodes = localeCodes
    }

    /**
     A wrapper method to synchronize data from Contentful to your local data store. The callback for this
     method is thread safe and will delegate to the thread that your data store is tied to.
     
     Execute queries on your local data store in the callback for this method.
     */
    public func sync(then completion: @escaping ResultsHandler<SyncSpace>) {

        let safeCompletion: ResultsHandler<SyncSpace> = { [weak self] result in
            self?.persistentStore.performBlock {
                completion(result)
            }
        }

        if let syncToken = self.syncToken {
            client?.nextSync(for: SyncSpace(syncToken: syncToken), then: safeCompletion)
        } else {
            client?.initialSync(then: safeCompletion)
        }
    }

    /// The Contentful.Client that is configured to retrieve data from your Contentful space.
    public var client: Client?

    /// The localization scheme with which to synchronize your Contentful space to your data store.
    public var localizationScheme: LocalizationScheme

    fileprivate let persistenceModel: PersistenceModel

    fileprivate let persistentStore: PersistenceStore

    public var syncToken: String? {
        var syncToken: String? = nil
        persistentStore.performAndWait {
            syncToken = self.fetchSpace().syncToken
        }
        return syncToken
    }

    public func performAndWait(block: @escaping () -> Void) {
        persistentStore.performAndWait {
            block()
        }
    }

    public func update(with syncSpace: SyncSpace) {
        persistentStore.performBlock { [weak self] in
            for asset in syncSpace.assets {
                self?.create(asset: asset)
            }

            // Update and deduplicate all entries.
            for entry in syncSpace.entries {
                self?.create(entry: entry)
            }

            for deletedAssetId in syncSpace.deletedAssetIds {
                self?.delete(assetWithId: deletedAssetId)
            }

            for deletedEntryId in syncSpace.deletedEntryIds {
                self?.delete(entryWithId: deletedEntryId)
            }

            self?.update(syncToken: syncSpace.syncToken)
            self?.resolveRelationships()
            self?.save()
        }
    }

    public func update(syncToken: String) {
        let space = self.fetchSpace()
        space.syncToken = syncToken
    }

    public func resolveRelationships() {

        let cache = DataCache(persistenceStore: persistentStore,
                              assetType: persistenceModel.assetType,
                              entryTypes: persistenceModel.entryTypes)

        for (entryId, fields) in relationshipsToResolve {
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
                    // Nullifiy the link if it's nil.
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
        switch localizationScheme {
        case .default:
            // Don't change the locale.
            createLocalized(asset: asset)
        case .all:
            for localeCode in localeCodes {
                asset.setLocale(withCode: localeCode)
                createLocalized(asset: asset)
            }
        case .one(let localeCode):
            asset.setLocale(withCode: localeCode)
            createLocalized(asset: asset)
        }
    }

    private func createLocalized(asset: Asset) {
        let type = persistenceModel.assetType

        let fetchPredicate = predicate(for: asset.id, localeCode: asset.currentlySelectedLocale.code)
        let fetched: [AssetPersistable]? = try? self.persistentStore.fetchAll(type: type, predicate: fetchPredicate)
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

        // Set the localeCode.
        persistable.localeCode = asset.currentlySelectedLocale.code
    }

    /** Never call this directly.
     This function is public as a side-effect of implementing `SyncSpaceDelegate`.

     - parameter entry: The newly created Entry
     */
    public func create(entry: Entry) {
        switch localizationScheme {
        case .default:
            // Don't change the locale.
            createLocalized(entry: entry)
        case .all:
            for localeCode in localeCodes {
                entry.setLocale(withCode: localeCode)
                createLocalized(entry: entry)
            }
        case .one(let localeCode):
            entry.setLocale(withCode: localeCode)
            createLocalized(entry: entry)
        }
    }

    private func createLocalized(entry: Entry) {

        guard let contentTypeId = entry.sys.contentTypeId else { return }
        guard let type = persistenceModel.entryTypes.filter({ $0.contentTypeId == contentTypeId }).first else { return }

        let fetchPredicate = predicate(for: entry.id, localeCode: entry.currentlySelectedLocale.code)
        let fetched: [EntryPersistable]? = try? self.persistentStore.fetchAll(type: type, predicate: fetchPredicate)
        let persistable: EntryPersistable

        if let fetched = fetched?.first {
            persistable = fetched
        } else {
            do {
                persistable = try self.persistentStore.create(type: type)
                persistable.id = entry.id
            } catch let error {
                fatalError("Could not create the Entry persistent store\n \(error)")
            }
        }

        // Populate persistable with sys and fields data from the `Entry`
        persistable.updatedAt = entry.sys.updatedAt
        persistable.createdAt = entry.sys.createdAt

        // Set the localeCode.
        persistable.localeCode = entry.currentlySelectedLocale.code


        // Update all properties and cache relationships to be resolved.
        self.updatePropertyFields(for: persistable, of: type, with: entry)

        // The key has locale information.
        let entryKey = DataCache.cacheKey(for: entry)
        self.relationshipsToResolve[entryKey] = self.persistableRelationships(for: persistable, of: type, with: entry)
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

    // Dictionary mapping Entry id's concatenated with locale code to a dictionary with fieldName to related entry id's.
    fileprivate var relationshipsToResolve = [String: [FieldName: Any]]()

    // Dictionary to cache mappings for fields on `Entry` to `EntryPersistable` properties for each content type.
    fileprivate var cachedPropertyMappingForContentTypeId: [ContentTypeId: [FieldName: String]] = [ContentTypeId: [FieldName: String]]()

    fileprivate var cachedRelationshipMappingForContentTypeId: [ContentTypeId: [FieldName: String]] = [ContentTypeId: [FieldName: String]]()

    // Returns regular (non-relationship) field to property mappings.
    internal func propertyMapping(for entryType: EntryPersistable.Type,
                                  and fields: [FieldName: Any]) -> [FieldName: String] {

            if let cachedPropertyMapping = cachedPropertyMappingForContentTypeId[entryType.contentTypeId] {
            return cachedPropertyMapping
        }

        // Filter out user-defined properties that represent relationships.
        guard let persistentRelationshipPropertyNames = try? persistentStore.relationships(for: entryType) else {
            assertionFailure("Could not filter out user-defined properties that represent relationships.")
            return [:]
        }

        // If user-defined relationship properties exist, use them, but filter out relationships.
        let mapping = entryType.fieldMapping()

        let relationshipPropertyNamesToExclude = Set(persistentRelationshipPropertyNames).intersection(Set(mapping.values))
        let filteredMapping = mapping.filter { (_, propertyName) -> Bool in
            return relationshipPropertyNamesToExclude.contains(propertyName) == false
        }

        // Cache.
        cachedPropertyMappingForContentTypeId[entryType.contentTypeId] = filteredMapping
        return filteredMapping
    }

    internal func relationshipMapping(for entryType: EntryPersistable.Type,
                                      and fields: [FieldName: Any]) -> [FieldName: String] {

        if let cachedRelationshipMapping = cachedRelationshipMappingForContentTypeId[entryType.contentTypeId] {
            return cachedRelationshipMapping
        }

        // Filter out user-defined regular fields that do NOT represent relationships.
        guard let persistentPropertyNames = try? persistentStore.properties(for: entryType) else {
            assertionFailure("Could not filter out user-defined regular fields that do NOT represent relationships.")
            return [:]
        }

        let mapping = entryType.fieldMapping()
        let propertyNamesToExclude = Set(persistentPropertyNames).intersection(Set(mapping.values))

        let filteredMapping = mapping.filter { (_, propertyName) -> Bool in
            return propertyNamesToExclude.contains(propertyName) == false
        }

        // Cache.
        cachedRelationshipMappingForContentTypeId[entryType.contentTypeId] = filteredMapping
        return filteredMapping
    }

    fileprivate func updatePropertyFields(for entryPersistable: EntryPersistable,
                                          of type: EntryPersistable.Type,
                                          with entry: Entry) {

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
                    relationships[propertyName] = targets.map { $0.id + "_" + entry.currentlySelectedLocale.code }
                } else {
                    // One-to-one.
                    assert(linkedValue is Link)
                    relationships[propertyName] = (linkedValue as! Link).id + "_" + entry.currentlySelectedLocale.code
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
