//
//  ContentfulSynchronizer.swift
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
public class ContentfulSynchronizer: SyncSpaceDelegate {
    fileprivate let client: Client
    fileprivate let matching: [String: AnyObject]
    fileprivate let store: PersistenceStore

    fileprivate var mappingForEntries = [String: [String: String]]()
    fileprivate var mappingForAssets: [String: String]!

    fileprivate var typeForAssets: Asset.Type!
    // Dictionary mapping contentTypeId's to Types
    fileprivate var typeForEntries = [String: Resource.Type]()
    fileprivate var typeForSpaces: Space.Type!

    // Dictionary mapping Entry identifier's to a dictionary with fieldName to related entry id's.
    fileprivate var relationshipsToResolve = [String: [String: Any]]()

    var syncToken: String? {
        return fetchSpace().syncToken
    }

    /**
     Instantiate a new ContentfulSynchronizer.

     - parameter client:           The API client to use for synchronization
     - parameter persistenceStore: The persistence store to use for storage
     - parameter matching:         An optional query for syncing specific content, 
                                   see <https://www.contentful.com/developers/docs/references/content-delivery-api/#/
                                        reference/synchronization/initial-synchronisation-of-entries-of-a-specific-content-type>

     - returns: An initialised instance of ContentfulSynchronizer
     */
    public init(client: Client, persistenceStore: PersistenceStore, matching: [String: AnyObject] = [String: AnyObject]()) {
        self.client = client
        self.matching = matching
        self.store = persistenceStore
    }

    /**
     Specify the type that Entries of a specific Content Type should be mapped to.

     The given type needs to implement the `Resource` protocol. Optionally, a field mapping can be
     provided which specifies the mapping between Contentful fields and properties of the target type.

     By default, this mapping will be automatically derived through matching fields and properties which
     share the same name. If you are using the Contentful Xcode plugin to generate your data model, the
     assumptions of the default mapping should usually suffice.

     - parameter contentTypeId:   ID of the Content Type which is being mapped
     - parameter type:            The type Entries should be mapped to (needs to implement the `Resource` protocol)
     - parameter propertyMapping: Optional mapping between Contentful fields and object properties
     */
    public func map(contentTypeId: String, to type: Resource.Type, propertyMapping: [String:String]? = nil) {
        mappingForEntries[contentTypeId] = propertyMapping
        typeForEntries[contentTypeId] = type
    }

    /**
     Specify the type that Assets should be mapped to.

     The given type needs to implement the `Asset` protocol. Optionally, a field mapping can be
     provided which specifies the mapping between Contentful fields and properties of the target type.

     By default, this mapping will be automatically derived through matching fields and properties which
     share the same name. For this, also the sub-fields of the `file` and `file.details.image` fields
     are being taken into consideration, e.g. if your type has a `width` property, the image width
     provided by Contentful would be mapped to it.

     - parameter type:            The type Assets should be mapped to (needs to implement the `Asset` protocol)
     - parameter propertyMapping: Optional mapping between Contentful fields and object properties
     */
    public func mapAssets(to type: Asset.Type, propertyMapping: [String:String]? = nil) {
        mappingForAssets = propertyMapping
        typeForAssets = type
    }

    /**
     Specify the type that Spaces are mapped to.

     The given type needs to implement the `Space` protocol.

     - parameter type: The type Spaces should be mapped to (needs to implement the `Space` protocol)
     */
    public func mapSpaces(to type: Space.Type) {
        typeForSpaces = type
    }

    /**
     Perform a synchronization. This will fetch new content from Contentful and save it to the
     persistent store.

     - parameter completion: A completion handler which is called after completing the sync process.
     */
    public func sync(_ completion: @escaping (Bool) -> Void) {
        assert(typeForAssets != nil, "Define a type for Assets using mapAssets(to:)")
        assert(typeForEntries.first?.1 != nil, "Define a type for Entries using map(contentTypeId:to:)")
        assert(typeForSpaces != nil, "Define a type for Spaces using mapSpaces(to:)")

        var initial: Bool?

        let syncCompletion: (Result<SyncSpace>) -> Void = { result in

            switch result {
            case .success(let syncSpace):

                // Fetch the current space
                let space = self.fetchSpace()
                space.syncToken = syncSpace.syncToken

                assert(space.syncToken != nil)

                // Delegate callback will createEntries when necessary.
                if let initial = initial, initial == true {

                    for asset in syncSpace.assets {
                        self.create(asset: asset)
                    }
                    for entry in syncSpace.entries {
                        self.create(entry: entry)
                    }
                }

                self.resolveRelationships()
                _ = try? self.store.save()
                completion(true)

            case .error(let error):
                NSLog("Error: \(error)")
                completion(false)
            }
        }

        if let syncToken = syncToken {
            initial = false
            let syncSpace = SyncSpace(client: client, syncToken: syncToken, delegate: self)
            syncSpace.sync(matching: matching, completion: syncCompletion)
        } else {
            initial = true
            client.initialSync(completion: syncCompletion)
        }

        relationshipsToResolve.removeAll()
    }

    // MARK: - Helpers

    // Attempts to fetch the object from the the persistent store, if it exists,
    fileprivate func create(_ identifier: String, fields: [String: Any], type: Resource.Type, mapping: [String: String]) {
        assert(mapping.count > 0, "Empty mapping for \(type)")

        let fetched: [Resource]? = try? store.fetchAll(type: type, predicate: predicate(for: identifier))
        let persisted: Resource

        if let fetched = fetched?.first {
            persisted = fetched
        } else {
            persisted = try! store.create(type: type)
            persisted.id = identifier
        }

        if let persisted = persisted as? NSObject {
            map(fields, to: persisted, mapping: mapping)
        }
    }

    fileprivate func deriveMapping(_ fields: [String], type: Resource.Type, prefix: String = "") -> [String: String] {
        var mapping = [String: String]()
        let properties = (try! store.properties(for: type)).filter { propertyName in
            fields.contains(propertyName)
        }
        properties.forEach { mapping["\(prefix)\($0)"] = $0 }
        return mapping
    }

    fileprivate func fetchSpace() -> Space {
        let createNewPersistentSpace: () -> (Space) = {
            return try! self.store.create(type: self.typeForSpaces)
        }

        guard let fetchedResults = try? self.store.fetchAll(type: self.typeForSpaces, predicate: NSPredicate(value: true)) as [Space] else {
            return createNewPersistentSpace()
        }

        assert(fetchedResults.count <= 1)

        guard let space = fetchedResults.first else {
            return createNewPersistentSpace()
        }

        return space
    }

    fileprivate func map(_ fields: [String: Any], to: NSObject, mapping: [String: String]) {
        for (mapKey, mapValue) in mapping {

            var fieldValue = fields.value(forKeyPath: mapKey)

            if let string = fieldValue as? String, string.hasPrefix("//") && mapValue == "url" {
                fieldValue = "https:\(string)"
            }

            // handle symbol arrays
            if let array = fieldValue as? NSArray {
                fieldValue = NSKeyedArchiver.archivedData(withRootObject: array)
            }

            to.setValue(fieldValue as? NSObject, forKeyPath: mapValue)
        }
    }

    fileprivate func resolveRelationships() {
        let entryTypes = typeForEntries.map { _, type in
            return type
        }
        let cache = DataCache(persistenceStore: store, assetType: typeForAssets, entryTypes: entryTypes)

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
    }

    // MARK: - SyncSpaceDelegate

    /**
     This function is public as a side-effect of implementing `SyncSpaceDelegate`.

     - parameter asset: The newly created Asset
     */
    public func create(asset: Contentful.Asset) {
        if mappingForAssets == nil {
            mappingForAssets = deriveMapping(Array(asset.fields.keys), type: typeForAssets)

            ["file", "file.details.image"].forEach {
                if let fileFields = asset.fields.value(forKeyPath: $0) as? [String: AnyObject] {
                    mappingForAssets! = mappingForAssets! + deriveMapping(Array(fileFields.keys), type: typeForAssets, prefix: "\($0).")
                }
            }
        }

        create(asset.id, fields: asset.fields, type: typeForAssets, mapping: mappingForAssets)
    }

    fileprivate func getIdentifier(_ target: Any) -> String? {
        if let target = target as? Contentful.Asset {
            return target.id
        }

        if let target = target as? Entry {
            return target.id
        }

        // For links that have not yet been resolved.
        if let jsonObject = target as? [String:AnyObject],
            let sys = jsonObject["sys"] as? [String:AnyObject],
            let identifier = sys["id"] as? String {
            return identifier
        }

        return nil
    }

    /**
     This function is public as a side-effect of implementing `SyncSpaceDelegate`.

     - parameter entry: The newly created Entry
     */
    public func create(entry: Entry) {

        if let contentTypeId = entry.sys.contentTypeId, let type = typeForEntries[contentTypeId] {
            var mapping = mappingForEntries[contentTypeId]
            if mapping == nil {
                mapping = deriveMapping(Array(entry.fields.keys), type: type)
            }

            create(entry.id, fields: entry.fields, type: type, mapping: mapping!)

            // ContentTypeId to either a single entry id or an array of entry id's to be linked.
            var relationships = [String: Any]()

            // Get fieldNames which are links/relationships/references to other types.
            if let relationshipNames = try? store.relationships(for: type) {

                for relationshipName in relationshipNames {

                    if let target = entry.fields[relationshipName] {
                        if let targets = target as? [Any] {
                            // One-to-many.
                            relationships[relationshipName] = targets.flatMap { self.getIdentifier($0) }
                        } else if let targets = target as? [AnyObject] {
                            // Workaround for when cast to [Any] fails; generally when the array still contains
                            // Dictionary respresentation of link.
                            relationships[relationshipName] = targets.flatMap { self.getIdentifier($0) }
                        } else {
                            // One-to-one.
                            relationships[relationshipName] = getIdentifier(target)
                        }
                    }
                }
            }

            relationshipsToResolve[entry.id] = relationships
        }
    }

    /**
     This function is public as a side-effect of implementing `SyncSpaceDelegate`.

     - parameter assetId: The ID of the deleted Asset
     */
    public func delete(assetWithId: String) {
        _ = try? store.delete(type: typeForAssets, predicate: predicate(for: assetWithId))
    }

    /**
     This function is public as a side-effect of implementing `SyncSpaceDelegate`.

     - parameter entryId: The ID of the deleted Entry
     */
    public func delete(entryWithId: String) {
        let predicate = ContentfulPersistence.predicate(for: entryWithId)

        typeForEntries.forEach {
            _ = try? self.store.delete(type: $0.1, predicate: predicate)
        }
    }
}
