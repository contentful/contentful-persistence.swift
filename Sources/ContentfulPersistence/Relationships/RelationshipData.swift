//
//  ContentfulPersistence
//

import Foundation

struct RelationshipData: Codable {

    typealias ParentId = String
    typealias ChildId = String
    struct FieldLocaleKey: Codable, Hashable {
        let parentId: ParentId
        let field: String
        let locale: String?
    }

    // quick access to all child ids by parent and relation type
    private var childIdsByParent = [ParentId: Set<ChildId>]()
    // quick access to all field/locale relationships by child id
    private(set) internal var toOneRelationShiptsByEntryId = [ChildId: [FieldLocaleKey: ToOneRelationship]]()
    private(set) internal var toManyRelationShipsbyEntryId = [ChildId: [FieldLocaleKey: ToManyRelationship.Id]]()
    private var toManyRelationShips = [ToManyRelationship.Id: ToManyRelationship]()

    var isEmpty: Bool {
        toOneRelationShiptsByEntryId.isEmpty && toManyRelationShipsbyEntryId.isEmpty
    }

    var count: Int {
        let numberOfToOneRelationships = toOneRelationShiptsByEntryId.values.map { $0.count }.reduce(0, +)
        return numberOfToOneRelationships + toManyRelationShips.count
    }

    static let empty: RelationshipData = .init(
        childIdsByParent: [:],
        toOneRelationShiptsByEntryId: [:],
        toManyRelationShipsbyEntryId: [:],
        toManyRelationShips: [:]
    )

    mutating func append(_ relationship: Relationship) {
        switch relationship {
        case .toMany(let nested):
            let fieldKey = FieldLocaleKey(parentId: nested.parentId, field: nested.fieldName, locale: nested.childIds.first?.localeCode)
            let childIds = Set(nested.childIds.map { $0.id })
            // append quick access cache
            childIdsByParent[nested.parentId] = (childIdsByParent[nested.parentId] ?? Set()).union(nested.childIds.map { $0.id })

            let relationShipId = nested.id
            toManyRelationShips[relationShipId] = nested

            for childId in childIds {
                var relationsByFieldAndLocale = toManyRelationShipsbyEntryId[childId] ?? [:]
                relationsByFieldAndLocale[fieldKey] = relationShipId
                toManyRelationShipsbyEntryId[childId] = relationsByFieldAndLocale
            }

        case .toOne(let nested):
            let fieldKey = FieldLocaleKey(parentId: nested.parentId, field: nested.fieldName, locale: nested.childId.localeCode)
            // append quick access cache
            childIdsByParent[nested.parentId] = (childIdsByParent[nested.parentId] ?? Set()).union([nested.childId.id])

            var relationsByFieldAndLocale = toOneRelationShiptsByEntryId[nested.childId.id] ?? [:]
            relationsByFieldAndLocale[fieldKey] = nested
            toOneRelationShiptsByEntryId[nested.childId.id] = relationsByFieldAndLocale
        }
    }

    mutating func delete(parentId: String) {
        guard var childIdsByParent = childIdsByParent[parentId] else { return }

        for childId in childIdsByParent {

            var emptyToOne = false
            var emptyToMany = false

            if var toOne = toOneRelationShiptsByEntryId[childId] {
                let keyForParent = toOne.keys.filter { $0.parentId == parentId }
                keyForParent.forEach { toOne[$0] = nil }
                emptyToOne = toOne.isEmpty
                toOneRelationShiptsByEntryId[childId] = emptyToOne ? nil : toOne
            } else {
                emptyToOne = true
            }

            if var toMany = toManyRelationShipsbyEntryId[childId] {
                let keyForParent = toMany.keys.filter { $0.parentId == parentId }
                keyForParent.forEach { toMany[$0] = nil }
                emptyToMany = toMany.isEmpty
                toManyRelationShipsbyEntryId[childId] = emptyToMany ? nil : toMany
            } else {
                emptyToMany = true
            }

            // remove unused parent
            if emptyToOne && emptyToMany {
                childIdsByParent.remove(childId)
            }
        }
        self.childIdsByParent[parentId] = childIdsByParent.isEmpty ? nil : childIdsByParent

        cleanup()
    }

    mutating func delete(parentId: ParentId, fieldName: String, localeCode: String?) {

        guard var childIdsByParent = childIdsByParent[parentId] else { return }

        let fieldKey = FieldLocaleKey(parentId: parentId, field: fieldName, locale: localeCode)

        for childId in childIdsByParent {
            var emptyToOne = false
            var emptyToMany = false

            if var toOne = toOneRelationShiptsByEntryId[childId] {
                toOne[fieldKey] = nil
                emptyToOne = toOne.isEmpty
                toOneRelationShiptsByEntryId[childId] = emptyToOne ? nil : toOne
            } else {
                emptyToOne = true
            }

            if var toMany = toManyRelationShipsbyEntryId[childId] {
                toMany[fieldKey] = nil
                emptyToMany = toMany.isEmpty
                toManyRelationShipsbyEntryId[childId] = emptyToMany ? nil : toMany
            } else {
                emptyToMany = true
            }

            // remove unused parent
            if emptyToOne && emptyToMany {
                childIdsByParent.remove(childId)
            }
        }

        self.childIdsByParent[parentId] = childIdsByParent.isEmpty ? nil : childIdsByParent

        cleanup()
    }

    func findToOne(childId: ChildId, localeCode: String?) -> [ToOneRelationship] {
        guard let relations = toOneRelationShiptsByEntryId[childId] else { return [] }

        return relations.keys
            .filter { $0.locale == localeCode }
            .compactMap { relations[$0] }
    }

    func findToMany(childId: ChildId, localeCode: String?) -> [ToManyRelationship] {
        guard let relations = toManyRelationShipsbyEntryId[childId] else { return [] }

        return relations.keys
            .filter { $0.locale == localeCode }
            .compactMap { relations[$0] }
            .compactMap { toManyRelationShips[$0] }
    }

    private mutating func cleanup() {
        // remove unused to many references
        let stored = Set(toManyRelationShips.keys)
        let used = Set(toManyRelationShipsbyEntryId.map { $0.value.map { $0.value } }.flatMap { $0 })

        stored.subtracting(used).forEach {
            toManyRelationShips[$0] = nil
        }
    }
}

extension ToManyRelationship: Identifiable {
    typealias Id = String
    var id: Id {
        ([parentType, parentId, fieldName, childIds.first?.localeCode ?? "-"] + childIds.map { $0.id }.sorted()).joined(separator: ",")
    }
}

extension ToOneRelationship: Identifiable {
    typealias Id = String
    var id: Id {
        [parentType, parentId, fieldName, childId.id, childId.localeCode ?? "-"].joined(separator: ",")
    }
}
