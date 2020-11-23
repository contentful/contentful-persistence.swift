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
    private var toOneRelationShips = Set<ToOneRelationship.Id>()

    var isEmpty: Bool {
        toOneRelationShips.isEmpty && toManyRelationShipsbyEntryId.isEmpty
    }

    var count: Int {
        toOneRelationShips.count + toManyRelationShips.count
    }

    static let empty: RelationshipData = .init()

    mutating func append(_ relationship: Relationship) {
        switch relationship {
        case .toMany(let nested):
            
            let relationShipId = nested.id
            guard toManyRelationShips[relationShipId] == nil else { return }
            
            let fieldKey = FieldLocaleKey(parentId: nested.parentId, field: nested.fieldName, locale: nested.childIds.first?.localeCode)
                        
            let childIds = Set(nested.childIds.map { $0.id })
            // append quick access cache
            var current = childIdsByParent[nested.parentId] ?? Set()
            current.formUnion(nested.childIds.map { $0.id })
            childIdsByParent[nested.parentId] = current

            
            toManyRelationShips[relationShipId] = nested

            for childId in childIds {
                var relationsByFieldAndLocale = toManyRelationShipsbyEntryId[childId] ?? [:]
                relationsByFieldAndLocale[fieldKey] = relationShipId
                toManyRelationShipsbyEntryId[childId] = relationsByFieldAndLocale
            }

        case .toOne(let nested):
            guard !toOneRelationShips.contains(nested.id) else { return }
            toOneRelationShips.insert(nested.id)
            
            let fieldKey = FieldLocaleKey(parentId: nested.parentId, field: nested.fieldName, locale: nested.childId.localeCode)
            // append quick access cache
            
            var current = childIdsByParent[nested.parentId] ?? Set()
            current.insert(nested.childId.id)
            
            childIdsByParent[nested.parentId] = current

            var relationsByFieldAndLocale = toOneRelationShiptsByEntryId[nested.childId.id] ?? [:]
            relationsByFieldAndLocale[fieldKey] = nested
            toOneRelationShiptsByEntryId[nested.childId.id] = relationsByFieldAndLocale
        }
    }

    mutating func delete(parentId: ParentId) {
        guard var childIdsByParent = childIdsByParent[parentId] else { return }

        for childId in childIdsByParent {

            var emptyToOne = false
            var emptyToMany = false

            if var toOne = toOneRelationShiptsByEntryId[childId] {
                let keyForParent = toOne.keys.filter { $0.parentId == parentId }
                keyForParent.forEach {
                    if let relation = toOne[$0] {
                        toOne[$0] = nil
                        toOneRelationShips.remove(relation.id)
                    }
                }
                emptyToOne = toOne.isEmpty
                toOneRelationShiptsByEntryId[childId] = emptyToOne ? nil : toOne
            } else {
                emptyToOne = true
            }

            if var toMany = toManyRelationShipsbyEntryId[childId] {
                let keyForParent = toMany.keys.filter { $0.parentId == parentId }
                keyForParent.forEach {
                    if let relationId = toMany[$0] {
                        toMany[$0] = nil
                        toManyRelationShips.removeValue(forKey: relationId)
                    }
                }
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
    }

    mutating func delete(parentId: ParentId, fieldName: String, localeCode: String?) {

        guard var childIdsByParent = childIdsByParent[parentId] else { return }

        let fieldKey = FieldLocaleKey(parentId: parentId, field: fieldName, locale: localeCode)

        for childId in childIdsByParent {
            var emptyToOne = false
            var emptyToMany = false

            if var toOne = toOneRelationShiptsByEntryId[childId] {
                if let relation = toOne[fieldKey] {
                    toOne[fieldKey] = nil
                    toOneRelationShips.remove(relation.id)
                }
                emptyToOne = toOne.isEmpty
                toOneRelationShiptsByEntryId[childId] = emptyToOne ? nil : toOne
            } else {
                emptyToOne = true
            }

            if var toMany = toManyRelationShipsbyEntryId[childId] {
                if let relationId = toMany[fieldKey] {
                    toMany[fieldKey] = nil
                    toManyRelationShips.removeValue(forKey: relationId)
                }
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
}
