//
//  ContentfulPersistence
//

import Foundation
import Contentful

struct RelationshipData: Codable {

    private typealias FieldId = String
    private typealias ChildLookupKey = String

    private struct RelationshipKeyPath: Codable, Hashable {

        var parentId: Relationship.ParentId
        var fieldId: FieldId

        init(parentId: Relationship.ParentId, fieldName: Relationship.FieldName, localeCode: Relationship.LocaleCode) {
            let fieldId = "\(fieldName),\(localeCode ?? "-")"
            self.init(parentId: parentId, fieldId: fieldId)
        }

        init(parentId: Relationship.ParentId, fieldId: FieldId) {
            self.parentId = parentId
            self.fieldId = fieldId
        }

    }

    var count: Int {
        relationships.reduce(0) { $0 + $1.value.count }
    }

    var isEmpty: Bool {
        relationships.isEmpty
    }

    private var relationships: [Relationship.ParentId: [FieldId: Relationship]] = [:]
    private var relationshipKeyPathsByChild: [RelationshipChildId.RawValue: Set<RelationshipKeyPath>] = [:]

    mutating func append(_ relationship: Relationship) {
        let keyPath = Self.keyPath(for: relationship)
        setRelationship(relationship, for: keyPath)
    }

    mutating func delete(parentId: Relationship.ParentId) {
        let keyPaths = relationships[parentId]?.keys
            .map { RelationshipKeyPath(parentId: parentId, fieldId: $0) } ?? []

        for keyPath in keyPaths {
            setRelationship(nil, for: keyPath)
        }
    }

    mutating func delete(parentId: Relationship.ParentId, fieldName: Relationship.FieldName, localeCode: Relationship.LocaleCode) {
        let keyPath = RelationshipKeyPath(parentId: parentId, fieldName: fieldName, localeCode: localeCode)
        setRelationship(nil, for: keyPath)
    }

    func relationships(for childId: RelationshipChildId) -> [Relationship] {
        relationshipKeyPathsByChild[childId.rawValue]?
            .compactMap(relationship) ?? []
    }

    private func relationship(keyPath: RelationshipKeyPath) -> Relationship? {
        relationships[keyPath.parentId]?[keyPath.fieldId]
    }

    private mutating func setRelationship(_ relationship: Relationship?, for keyPath: RelationshipKeyPath) {
        var relationshipsByFieldIdentifier = relationships[keyPath.parentId] ?? [:]

        let newChildIds = Set(relationship?.children.elements.map { $0.id } ?? [])

        if let existingRelationship = relationshipsByFieldIdentifier[keyPath.fieldId] {
            let existingChildIds = Set(existingRelationship.children.elements.map { $0.id })
            let removedChildIds = existingChildIds.subtracting(newChildIds)

            for childId in removedChildIds {
                if var keyPaths = relationshipKeyPathsByChild[childId] {
                    keyPaths.remove(keyPath)
                    relationshipKeyPathsByChild[childId] = keyPaths
                }
            }
        }

        for childId in newChildIds {
            var keyPaths = relationshipKeyPathsByChild[childId] ?? Set()
            keyPaths.insert(keyPath)
            relationshipKeyPathsByChild[childId] = keyPaths
        }

        relationshipsByFieldIdentifier[keyPath.fieldId] = relationship

        if relationshipsByFieldIdentifier.isEmpty {
            relationships[keyPath.parentId] = nil
        } else {
            relationships[keyPath.parentId] = relationshipsByFieldIdentifier
        }
    }

    private static func keyPath(for relationship: Relationship) -> RelationshipKeyPath {
        RelationshipKeyPath(parentId: relationship.parentId, fieldName: relationship.fieldName, localeCode: relationship.localeCode)
    }

}
