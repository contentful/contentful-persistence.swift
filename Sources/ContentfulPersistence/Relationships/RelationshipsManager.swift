//
//  ContentfulPersistenceSwift
//

import Foundation

/// Manages relationships of the entries using internal cache. It is used to recreate relationship when
/// unpublished entry is published again.
final class RelationshipsManager {

    private let cache: RelationshipCache

    var relationships: RelationshipData {
        cache.relationships
    }

    init(cacheFileName: String) {
        self.cache = RelationshipCache(cacheFileName: cacheFileName)
    }

    /// Creates one-to-one relationship if does not exist yet.
    func cacheToOneRelationship(
        parent: EntryPersistable,
        childId: String,
        fieldName: String
    ) {

        let parentType = type(of: parent).contentTypeId

        let relationship = Relationship(
            parentType: parentType,
            parentId: parent.id,
            fieldName: fieldName,
            childId: .init(value: childId)
        )

        cache.add(relationship: relationship)
    }

    func cacheToManyRelationship(
        parent: EntryPersistable,
        childIds: [String],
        fieldName: String
    ) {
        let theChildIds: [RelationshipChildId] = childIds.map { .init(value: $0) }
        let parentType = type(of: parent).contentTypeId

        let relationship = Relationship(
            parentType: parentType,
            parentId: parent.id,
            fieldName: fieldName,
            childIds: theChildIds
        )

        cache.add(relationship: relationship)
    }

    func delete(parentId: String) {
        cache.delete(parentId: parentId)
    }

    func delete(parentId: String, fieldName: String, localeCode: String?) {
        cache.delete(parentId: parentId, fieldName: fieldName, localeCode: localeCode)
    }

    func save() {
        cache.save()
    }
}
