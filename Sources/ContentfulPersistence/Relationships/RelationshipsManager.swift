//
//  ContentfulPersistenceSwift
//

import Foundation

///
final class RelationshipsManager {

    private let cache: RelationshipCache

    var relationships: [Relationship] {
        return cache.relationships
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
        let theChildId = RelationshipChildId(value: childId)
        delete(parentId: parent.id, fieldName: fieldName, localeCode: theChildId.localeCode)

        let parentType = type(of: parent).contentTypeId

        let relationship = ToOneRelationship(
            parentType: parentType,
            parentId: parent.id,
            fieldName: fieldName,
            childId: .init(value: childId)
        )

        cache.add(relationship: .toOne(relationship))
    }

    func cacheToManyRelationship(
        parent: EntryPersistable,
        childIds: [String],
        fieldName: String
    ) {
        let theChildIds: [RelationshipChildId] = childIds.map { .init(value: $0) }
        delete(parentId: parent.id, fieldName: fieldName, localeCode: theChildIds.first?.localeCode)

        let parentType = type(of: parent).contentTypeId

        let relationship = ToManyRelationship(
            parentType: parentType,
            parentId: parent.id,
            fieldName: fieldName,
            childIds: theChildIds
        )

        cache.add(relationship: .toMany(relationship))
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
