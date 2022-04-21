//
//  SynchronizationManager.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 30/03/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

import Contentful
import CoreData

func predicate(for id: String, localeCodes: [LocaleCode]) -> NSPredicate {
    return NSPredicate(format: "id == %@ AND localeCode IN %@", id, localeCodes)
}

func predicate(for id: String, localeCode: LocaleCode) -> NSPredicate {
    return NSPredicate(format: "id == %@ AND localeCode == %@", id, localeCode)
}

func predicate(for id: String) -> NSPredicate {
    return NSPredicate(format: "id == %@", id)
}

func predicate(ids: [String], localeCodes: [LocaleCode]) -> NSPredicate {
    return NSPredicate(format: "id IN %@ AND localeCode IN %@", ids, localeCodes)
}

func predicate(ids: [String], localeCode: LocaleCode) -> NSPredicate {
    return NSPredicate(format: "id IN %@ AND localeCode == %@", ids, localeCode)
}

func predicate(ids: [String]) -> NSPredicate {
    return NSPredicate(format: "id IN %@", ids)
}

// A sentinal value used to represent relationships that should be deleted in the `resolveRelationships()` method
let deletedRelationshipSentinel = -1

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

    private enum Constants {
        static let cacheFileName = "ContentfulPersistenceRelationships.data"
    }

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
        persistentStore = persistenceStore
        self.persistenceModel = persistenceModel
        self.localizationScheme = localizationScheme
        localeCodes = []

        if let client = client {
            client.persistenceIntegration = self
            self.client = client
        }
    }

    fileprivate var localeCodes: [LocaleCode]
    fileprivate let privateQueue: DispatchQueue = .init(label: "private.contentful.synchronization.service.queue")
    fileprivate let dispatchGroup: DispatchGroup = .init()

    public func update(localeCodes: [LocaleCode]) {
        switch localizationScheme {
        case let .one(localeCode):
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

     - parameter limit: Number of elements per page. See documentation for details.
     */
    public func sync(contentTypeIds: [String]? = nil, limit: Int? = nil, then completion: @escaping ResultsHandler<SyncSpace>) {
        resolveCachedRelationships { [weak self] in
            self?.syncSafely(contentTypeIds: contentTypeIds, limit: limit, then: completion)
        }
    }

    private func syncSafely(contentTypeIds: [String]?, limit: Int?, then completion: @escaping ResultsHandler<SyncSpace>) {
        let safeCompletion: ResultsHandler<SyncSpace> = { [weak self] result in
            self?.persistentStore.performBlock {
                completion(result)
            }
        }
        
        if let contentTypeIds = contentTypeIds {
            contentTypeIds.forEach { contentTypeId in
                dispatchGroup.enter()
                if let syncToken = getSyncToken(from: contentTypeId) {
                    client?.sync(for: SyncSpace(syncToken: syncToken, limit: limit, contentTypeId: contentTypeId), then: { [weak self] _ in
                        self?.dispatchGroup.leave()
                    })
                } else {
                    client?.sync(for: SyncSpace(limit: limit, contentTypeId: contentTypeId), syncableTypes: SyncSpace.SyncableTypes.entriesOfContentType(withId: contentTypeId), then: { [weak self] _ in
                        self?.dispatchGroup.leave()
                    })
                }
                
            }
            dispatchGroup.enter()
            if let assetsSyncToken = getSyncToken(from: "contentful_assets") {
                client?.sync(for: SyncSpace(syncToken: assetsSyncToken, limit: limit, contentTypeId: "contentful_assets"), then: { [weak self] _ in
                    self?.dispatchGroup.leave()
                })
            } else {
                client?.sync(for: SyncSpace(limit: limit, contentTypeId: "contentful_assets"), syncableTypes: SyncSpace.SyncableTypes.assets, then: { [weak self] _ in
                    self?.dispatchGroup.leave()
                })
            }
            dispatchGroup.enter()
            if let deletionsSyncToken = getSyncToken(from: "contentful_deleted") {
                client?.sync(for: SyncSpace(syncToken: deletionsSyncToken, limit: limit, contentTypeId: "contentful_deleted"), then: { [weak self] _ in
                    self?.dispatchGroup.leave()
                })
            } else {
                client?.sync(for: SyncSpace(limit: limit, contentTypeId: "contentful_deleted"), syncableTypes: SyncSpace.SyncableTypes.allDeletions, then: { [weak self] _ in
                    self?.dispatchGroup.leave()
                })
            }
            
            dispatchGroup.notify(queue: privateQueue) { [weak self] in
                self?.persistentStore.performAndWait {
                    self?.resolveRelationships()
                    self?.save()
                }
                safeCompletion(.success(.init()))
            }
        } else if let syncToken = getSyncToken(from: "") {
            client?.sync(for: SyncSpace(syncToken: syncToken, limit: limit), then: safeCompletion)
        } else {
            client?.sync(for: SyncSpace(limit: limit), then: safeCompletion)
        }
    }

    /// The Contentful.Client that is configured to retrieve data from your Contentful space.
    public var client: Client?

    /// The localization scheme with which to synchronize your Contentful space to your data store.
    public var localizationScheme: LocalizationScheme

    fileprivate let persistenceModel: PersistenceModel

    fileprivate let persistentStore: PersistenceStore

    public func getSyncToken(from contentTypeId: String) -> String? {
        var syncToken: String?
        persistentStore.performAndWait {
            syncToken = self.fetchSpace(for: contentTypeId).syncToken
        }
        return syncToken
    }

    public func performAndWait(block: @escaping () -> Void) {
        persistentStore.performAndWait {
            block()
        }
    }

    public func update(with syncSpace: SyncSpace) {
        persistentStore.performAndWait { [weak self] in
            self?.create(assets: syncSpace.assets)

            // Update and deduplicate all entries.
            self?.create(entries: syncSpace.entries)

            for deletedAssetId in syncSpace.deletedAssetIds {
                self?.delete(assetWithId: deletedAssetId)
            }

            for deletedEntryId in syncSpace.deletedEntryIds {
                self?.delete(entryWithId: deletedEntryId)
            }

//            self?.resolveRelationships()
            self?.update(syncSpace: syncSpace)

            // Only save updates to the persistence store if the sync is completed
            // (has no more pages). Else, non-optional relations whose nodes
            // are sent in different pages would fail to be stored. This is the
            // case because e.g. CoreData validates non-optional relations when
            // save() is called.
//            if syncSpace.hasMorePages == false {
//                self?.save()
//            }
        }
    }

    public func update(syncSpace: SyncSpace) {
        let space = fetchSpace(for: syncSpace.contentTypeId)
        space.syncToken = syncSpace.syncToken
        space.id = syncSpace.contentTypeId
    }

    public func resolveRelationships() {
        let cache = DataCache(persistenceStore: persistentStore,
                              assetType: persistenceModel.assetType,
                              entryTypes: persistenceModel.entryTypes)

        for (entryId, fields) in relationshipsToResolve {
            if let entryPersistable = cache.entry(for: entryId) {
                // Mutable copy of fields to link targets.
                var updatedFieldsRelationships: [FieldName: Any] = fields

                for (fieldName, relatedResourceId) in fields {
                    // Resolve one-to-one link.
                    if let identifier = relatedResourceId as? String {
                        relationshipsManager.cacheToOneRelationship(
                            parent: entryPersistable,
                            childId: identifier,
                            fieldName: fieldName
                        )

                        if let target = cache.item(for: identifier) {
                            entryPersistable.setValue(target, forKey: fieldName)
                            updatedFieldsRelationships.removeValue(forKey: fieldName)
                        }
                    }

                    // Resolve one-to-many links array.
                    if let identifiers = relatedResourceId as? [String] {
                        relationshipsManager.cacheToManyRelationship(
                            parent: entryPersistable,
                            childIds: identifiers,
                            fieldName: fieldName
                        )

                        let targets = identifiers.compactMap { cache.item(for: $0) }
                        entryPersistable.setValue(NSOrderedSet(array: targets), forKey: fieldName)

                        // Only clear links to be resolved array if all links in the array have been resolved.
                        if targets.count == identifiers.count {
                            updatedFieldsRelationships.removeValue(forKey: fieldName)
                        }
                    }

                    // Nullifiy the link if it's nil.
                    if let sentinel = relatedResourceId as? Int, sentinel == -1 {
                        entryPersistable.setValue(nil, forKey: fieldName)
                        updatedFieldsRelationships.removeValue(forKey: fieldName)
                        relationshipsManager.delete(
                            parentId: entryPersistable.id,
                            fieldName: fieldName,
                            localeCode: entryPersistable.localeCode
                        )
                    }
                }

                // Update the relationships that must be resolved.
                if updatedFieldsRelationships.isEmpty {
                    relationshipsToResolve.removeValue(forKey: entryId)
                } else {
                    relationshipsToResolve[entryId] = updatedFieldsRelationships
                }

                updateRelationships(with: entryPersistable, cache: cache)
            }
        }
        cacheUnresolvedRelationships()
    }

    /// Find and update relationships where the entry should be set as a child.
    private func updateRelationships(with entry: EntryPersistable, cache: DataCache) {
        updateToOneRelationships(with: entry, cache: cache)
        updateToManyRelationships(with: entry, cache: cache)
    }

    private func updateToOneRelationships(with entry: EntryPersistable, cache: DataCache) {
        let filteredRelationships: [ToOneRelationship] = relationshipsManager.relationships.findToOne(
            childId: entry.id,
            localeCode: entry.localeCode
        )

        for relationship in filteredRelationships {
            guard let parent = cache.entry(for: DataCache.cacheKey(for: relationship.parentId, localeCode: entry.localeCode)) else {
                return
            }
            parent.setValue(entry, forKey: relationship.fieldName)
        }
    }

    private func updateToManyRelationships(with entry: EntryPersistable, cache: DataCache) {
        let filteredRelationships: [ToManyRelationship] = relationshipsManager.relationships.findToMany(
            childId: entry.id,
            localeCode: entry.localeCode
        )

        for relationship in filteredRelationships {
            guard let parent = cache.entry(for: DataCache.cacheKey(for: relationship.parentId, localeCode: entry.localeCode)) else {
                return
            }

            guard let collection = parent.value(forKey: relationship.fieldName) else { continue }

            if let set = collection as? NSSet {
                let mutableSet = NSMutableSet(set: set)
                mutableSet.add(entry)
                parent.setValue(NSSet(set: mutableSet), forKey: relationship.fieldName)
            } else if let set = collection as? NSOrderedSet {
                var array = set.array
                array.append(entry)
                parent.setValue(NSOrderedSet(array: array), forKey: relationship.fieldName)
            }
        }
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
            createLocalized(asset: asset, localeCodes: [asset.currentlySelectedLocale.code])
        case .all:
            createLocalized(asset: asset, localeCodes: localeCodes)

        case let .one(localeCode):
            createLocalized(asset: asset, localeCodes: [localeCode])
        }
    }

    private func createLocalized(asset: Asset, localeCodes: [LocaleCode]) {
        let type = persistenceModel.assetType

        let fetchPredicate = predicate(for: asset.id, localeCodes: localeCodes)
        let fetchedAssets: [AssetPersistable] = (try? persistentStore.fetchAll(type: type, predicate: fetchPredicate)) ?? []
        let localeToAssetDict = Dictionary(grouping: fetchedAssets, by: { $0.localeCode })

        for localeCode in localeCodes {
            asset.setLocale(withCode: localeCode)

            let persistable: AssetPersistable
            if let fetched = localeToAssetDict[localeCode]?.first {
                persistable = fetched
            } else {
                do {
                    persistable = try persistentStore.create(type: type)
                } catch let error {
                    fatalError("Could not create the Asset persistent store\n \(error)")
                }
            }

            // Populate persistable with sys and fields data from the `Asset`
            persistable.id = asset.id // Set the localeCode.
            persistable.localeCode = asset.currentlySelectedLocale.code
            persistable.title = asset.title
            persistable.assetDescription = asset.description
            persistable.updatedAt = asset.sys.updatedAt
            persistable.createdAt = asset.sys.updatedAt
            persistable.urlString = asset.urlString
            persistable.fileName = asset.file?.fileName
            persistable.fileType = asset.file?.contentType
            if let size = asset.file?.details?.size {
                persistable.size = NSNumber(value: size)
            }
            if let height = asset.file?.details?.imageInfo?.height {
                persistable.height = NSNumber(value: height)
            }
            if let width = asset.file?.details?.imageInfo?.width {
                persistable.width = NSNumber(value: width)
            }
        }

    }

    /** Never call this directly.
     This function is public as a side-effect of implementing `SyncSpaceDelegate`.

     - parameter entry: The newly created Entry
     */
    public func create(entry: Entry) {
        switch localizationScheme {
        case .default:
            // Don't change the locale.
            createLocalized(entry: entry, localeCodes: [entry.currentlySelectedLocale.code])

        case .all:
            createLocalized(entry: entry, localeCodes: localeCodes)

        case let .one(localeCode):
            createLocalized(entry: entry, localeCodes: [localeCode])
        }
    }

    private func createLocalized(entry: Entry, localeCodes: [LocaleCode]) {

        guard let contentTypeId = entry.sys.contentTypeId else { return }
        guard let type = persistenceModel.entryTypes.filter({ $0.contentTypeId == contentTypeId }).first else { return }

        let fetchPredicate = predicate(for: entry.id, localeCodes: localeCodes)
        let fetchedEntries: [EntryPersistable] = (try? persistentStore.fetchAll(type: type, predicate: fetchPredicate)) ?? []
        let localeToEntryDict = Dictionary(grouping: fetchedEntries, by: { $0.localeCode })

        for localeCode in localeCodes {
            entry.setLocale(withCode: localeCode)
            let persistable: EntryPersistable

            if let fetched = localeToEntryDict[localeCode]?.first {
                persistable = fetched
            } else {
                do {
                    persistable = try persistentStore.create(type: type)
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
            updatePropertyFields(for: persistable, of: type, with: entry)

            // The key has locale information.
            let entryKey = DataCache.cacheKey(for: entry)
            relationshipsToResolve[entryKey] = persistableRelationships(for: persistable, of: type, with: entry)
        }
    }
    
    /**
     This function is public as a side-effect of implementing `PersistenceDelegate`.

     - parameter assets: The newly created Assets
     */
    public func create(assets: [Asset]) {
        switch localizationScheme {
        case .default:
            // Don't change the locale.
            createLocalized(assets: assets, localeCodes: [])
        case .all:
            createLocalized(assets: assets, localeCodes: localeCodes)

        case let .one(localeCode):
            createLocalized(assets: assets, localeCodes: [localeCode])
        }
    }

    private func createLocalized(assets: [Asset], localeCodes: [LocaleCode]) {
        let type = persistenceModel.assetType

        let fetchPredicate = localeCodes.isEmpty ? predicate(ids: assets.map { $0.id }) : predicate(ids: assets.map { $0.id }, localeCodes: localeCodes)
        let fetchedAssets: [AssetPersistable] = (try? persistentStore.fetchAll(type: type, predicate: fetchPredicate)) ?? []
        let localeToAssetDict = Dictionary(grouping: fetchedAssets, by: { "\($0.id)-\($0.localeCode ?? "")" })

        for asset in assets {
            let codes = localeCodes.isEmpty ? [asset.currentlySelectedLocale.code] : localeCodes
            for localeCode in codes {
                asset.setLocale(withCode: localeCode)

                let persistable: AssetPersistable
                if let fetched = localeToAssetDict["\(asset.id)-\(localeCode)"]?.first {
                    persistable = fetched
                } else {
                    do {
                        persistable = try persistentStore.create(type: type)
                    } catch let error {
                        fatalError("Could not create the Asset persistent store\n \(error)")
                    }
                }

                // Populate persistable with sys and fields data from the `Asset`
                persistable.id = asset.id // Set the localeCode.
                persistable.localeCode = asset.currentlySelectedLocale.code
                persistable.title = asset.title
                persistable.assetDescription = asset.description
                persistable.updatedAt = asset.sys.updatedAt
                persistable.createdAt = asset.sys.updatedAt
                persistable.urlString = asset.urlString
                persistable.fileName = asset.file?.fileName
                persistable.fileType = asset.file?.contentType
                if let size = asset.file?.details?.size {
                    persistable.size = NSNumber(value: size)
                }
                if let height = asset.file?.details?.imageInfo?.height {
                    persistable.height = NSNumber(value: height)
                }
                if let width = asset.file?.details?.imageInfo?.width {
                    persistable.width = NSNumber(value: width)
                }
            }
        }
    }

    /** Never call this directly.
     This function is public as a side-effect of implementing `SyncSpaceDelegate`.

     - parameter entries: The newly created Entries
     */
    public func create(entries: [Entry]) {
        switch localizationScheme {
        case .default:
            // Don't change the locale.
            createLocalized(entries: entries, localeCodes: [])

        case .all:
            createLocalized(entries: entries, localeCodes: localeCodes)

        case let .one(localeCode):
            createLocalized(entries: entries, localeCodes: [localeCode])
        }
    }

    private func createLocalized(entries: [Entry], localeCodes: [LocaleCode]) {
        let typeToEntry = Dictionary(grouping: entries, by: { $0.sys.contentTypeId })
        for typeId in typeToEntry.keys {
            guard let contentTypeId = typeId,
                  let type = persistenceModel.entryTypes.first(where: { $0.contentTypeId == contentTypeId }),
                  let typeEntries = typeToEntry[contentTypeId] else {
                continue
            }
            let fetchPredicate = localeCodes.isEmpty ? predicate(ids: typeEntries.map { $0.id }) : predicate(ids: typeEntries.map { $0.id }, localeCodes: localeCodes)
            let fetchedEntries: [EntryPersistable] = (try? persistentStore.fetchAll(type: type, predicate: fetchPredicate)) ?? []
            let localeToEntryDict = Dictionary(grouping: fetchedEntries, by: { "\($0.id)-\($0.localeCode ?? "")" })
            for entry in typeEntries {
                let codes = localeCodes.isEmpty ? [entry.currentlySelectedLocale.code] : localeCodes
                for localeCode in codes {
                    entry.setLocale(withCode: localeCode)
                    let persistable: EntryPersistable

                    if let fetched = localeToEntryDict["\(entry.id)-\(localeCode)"]?.first {
                        persistable = fetched
                    } else {
                        do {
                            persistable = try persistentStore.create(type: type)
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
                    updatePropertyFields(for: persistable, of: type, with: entry)

                    // The key has locale information.
                    let entryKey = DataCache.cacheKey(for: entry)
                    relationshipsToResolve[entryKey] = persistableRelationships(for: persistable, of: type, with: entry)
                }
            }
        }
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
            _ = try? persistentStore.delete(type: type, predicate: predicate)
        }

        relationshipsManager.delete(parentId: entryWithId)
    }

    public func save() {
        do {
            try persistentStore.save()
            relationshipsManager.save()
        } catch let error {
            assertionFailure("Could not save the persistent store\n \(error)")
        }
    }

    // MARK: Unresolved relationship caching

    /// The local URL where unresolved relationships are cached so that they may be resolved on future app launches. Useful for debugging.
    public var pendingRelationshipsURL: URL? {
        guard let url = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            return nil
        }
        return url.appendingPathComponent("ContentfulRelationshipsToResolve.data")
    }

    private func cacheUnresolvedRelationships() {
        guard let localURL = pendingRelationshipsURL else { return }

        if relationshipsToResolve.isEmpty {
            try? FileManager.default.removeItem(at: localURL)
            return
        }

        guard JSONSerialization.isValidJSONObject(relationshipsToResolve) else { return }

        guard let data = try? JSONSerialization.data(withJSONObject: relationshipsToResolve, options: []) else {
            return
        }
        try? data.write(to: localURL, options: [])
    }

    /// The unsresolved relationships that were cached to disk.
    public var cachedUnresolvedRelationships: [String: [FieldName: Any]]? {
        guard let localURL = pendingRelationshipsURL else { return nil }
        guard let data = try? Data(contentsOf: localURL, options: []) else {
            return nil
        }

        guard let relationships = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: [FieldName: Any]] else {
            return nil
        }

        return relationships
    }

    private func resolveCachedRelationships(completion: @escaping (() -> Void)) {
        guard let relationships = cachedUnresolvedRelationships, !relationships.isEmpty else {
            completion()
            return
        }

        persistentStore.performAndWait { [weak self] in
            self?.relationshipsToResolve = relationships
            self?.resolveRelationships()
            self?.save()
            completion()
        }
    }

    // MARK: Private
    private let relationshipsManager = RelationshipsManager(cacheFileName: Constants.cacheFileName)

    // Dictionary mapping source Entry id's concatenated with locale code to a dictionary with linking fieldName to target entry id's.
    internal var relationshipsToResolve = [String: [FieldName: Any]]()

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
            relationshipPropertyNamesToExclude.contains(propertyName) == false
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
            propertyNamesToExclude.contains(propertyName) == false
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

            let attributeType = persistable.entity.attributesByName[propertyName]?.attributeType
            // handle symbol arrays as NSData if field is of type .binaryDataAttributeType, otherwise use .transformableAttributeType
            if attributeType == .binaryDataAttributeType, let array = fieldValue as? [NSCoding] {
                fieldValue = NSKeyedArchiver.archivedData(withRootObject: array)
            }
            if attributeType == .dateAttributeType, let date = getDate(fieldValue as? String) {
                fieldValue = date
            }
            persistable.setValue(fieldValue, forKey: propertyName)
        }
    }

    fileprivate func getDate(_ fieldValue: String?) -> Date? {
        guard let value = fieldValue else { return nil }
        let formats: [String] = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd'T'HH:mmxxx",
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        ]
        let dateParser = DateFormatter()
        dateParser.locale = Locale(identifier: "en_US_POSIX")
        dateParser.timeZone = TimeZone(secondsFromGMT: 0)
        for format in formats {
            dateParser.dateFormat = format
            if let date = dateParser.date(from: value) {
                return date
            }
        }
        return nil
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
                relationships[propertyName] = deletedRelationshipSentinel
            }
        }

        return relationships
    }

    fileprivate func fetchSpace(for contentTypeId: String) -> SyncSpacePersistable {
        let createNewPersistentSpace: () -> (SyncSpacePersistable) = {
            do {
                let spacePersistable: SyncSpacePersistable = try self.persistentStore.create(type: self.persistenceModel.spaceType)
                spacePersistable.id = contentTypeId
                return spacePersistable
            } catch let error {
                fatalError("Could not create the Sync Space persistent store\n \(error)")
            }
        }

        guard let fetchedResults = try? persistentStore.fetchAll(type: persistenceModel.spaceType, predicate: NSPredicate(value: true)) as [SyncSpacePersistable] else {
            return createNewPersistentSpace()
        }

        guard let space = fetchedResults.first(where: { $0.id == contentTypeId }) else {
            return createNewPersistentSpace()
        }
        
        return space
    }
}
