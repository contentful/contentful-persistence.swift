//
//  ContentfulPersistence
//

import Foundation
import Contentful

struct RelationshipKeyPath: Codable, Hashable {

    var localeCode: Relationship.LocaleCode
    var parentId: Relationship.ParentId
    var fieldName: Relationship.FieldName

}

struct RelationshipData: Codable {

    typealias ChildId = String

    var count: Int {
        relationships.keys
            .flatMap { localeCode -> [Int] in
                relationships[localeCode]?.keys
                    .compactMap { relationships[localeCode]?[$0]?.count } ?? []
            }
            .reduce(0, +)
    }

    var isEmpty: Bool {
        relationships.isEmpty
    }

    private var relationships: [Relationship.LocaleCode: [Relationship.ParentId: [Relationship.FieldName: Relationship]]] = [:]
    private var relationshipKeyPathByChild: [ChildId: Set<RelationshipKeyPath>] = [:]

    mutating func append(_ relationship: Relationship) {
        let keyPath = Self.keyPath(for: relationship)
        setRelationship(relationship, for: keyPath)
    }

    mutating func delete(parentId: Relationship.ParentId) {
        let keyPaths = relationships.keys
            .flatMap { localeCode -> [RelationshipKeyPath] in
                relationships[localeCode]?[parentId]?.keys
                    .map { RelationshipKeyPath(localeCode: localeCode, parentId: parentId, fieldName: $0) } ?? []
            }

        for keyPath in keyPaths {
            setRelationship(nil, for: keyPath)
        }
    }

    mutating func delete(parentId: Relationship.ParentId, fieldName: Relationship.FieldName, localeCode: Relationship.LocaleCode) {
        let keyPath = RelationshipKeyPath(localeCode: localeCode, parentId: parentId, fieldName: fieldName)
        setRelationship(nil, for: keyPath)
    }

    func relationships(for childId: ChildId, with localeCode: Relationship.LocaleCode) -> [Relationship] {
        relationshipKeyPathByChild[childId]?
            .filter { $0.localeCode == localeCode }
            .compactMap(relationship) ?? []
    }

    private func relationship(keyPath: RelationshipKeyPath) -> Relationship? {
        relationships[keyPath.localeCode]?[keyPath.parentId]?[keyPath.fieldName]
    }

    private mutating func setRelationship(_ relationship: Relationship?, for keyPath: RelationshipKeyPath) {
        var relationshipsByParentId = relationships[keyPath.localeCode] ?? [:]
        var relationshipsByFieldName = relationshipsByParentId[keyPath.parentId] ?? [:]

        let newChildIds = Set(relationship?.children.elements.map { $0.id } ?? [])

        if let existingRelationship = relationshipsByFieldName[keyPath.fieldName] {
            let existingChildIds = Set(existingRelationship.children.elements.map { $0.id })
            let removedChildIds = existingChildIds.subtracting(newChildIds)

            for childId in removedChildIds {
                if var keyPaths = relationshipKeyPathByChild[childId] {
                    keyPaths.remove(keyPath)
                    relationshipKeyPathByChild[childId] = keyPaths
                }
            }
        }

        for childId in newChildIds {
            var keyPaths = relationshipKeyPathByChild[childId] ?? Set()
            keyPaths.insert(keyPath)
            relationshipKeyPathByChild[childId] = keyPaths
        }

        relationshipsByFieldName[keyPath.fieldName] = relationship

        if relationshipsByFieldName.isEmpty {
            relationshipsByParentId[keyPath.parentId] = nil
        } else {
            relationshipsByParentId[keyPath.parentId] = relationshipsByFieldName
        }

        if relationshipsByParentId.isEmpty {
            relationships[keyPath.localeCode] = nil
        } else {
            relationships[keyPath.localeCode] = relationshipsByParentId
        }
    }

    private static func keyPath(for relationship: Relationship) -> RelationshipKeyPath {
        RelationshipKeyPath(localeCode: relationship.localeCode, parentId: relationship.parentId, fieldName: relationship.fieldName)
    }

}
