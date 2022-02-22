//
//  ContentfulPersistenceSwift
//

import Contentful

/// Represents a relationship between two entries.
struct Relationship: Codable, Equatable, Identifiable {

    typealias ID = String
    typealias ParentId = String
    typealias FieldName = String
    typealias LocaleCode = String?

    enum Children: Codable, Equatable {

        private enum CodingKeys: CodingKey {
            case kind
            case value
        }

        private enum Kind: String, Codable {
            case one
            case many
        }

        case one(RelationshipChildId)
        case many([RelationshipChildId])

        var elements: [RelationshipChildId] {
            switch self {
            case .one(let relationshipChildId):
                return [relationshipChildId]
            case .many(let relationshipChildIds):
                return relationshipChildIds
            }
        }

        // MARK: Codable

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try container.decode(Kind.self, forKey: .kind)

            switch kind {
            case .one:
                self = .one(try container.decode(RelationshipChildId.self, forKey: .value))
            case .many:
                self = .many(try container.decode([RelationshipChildId].self, forKey: .value))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .one(let childId):
                try container.encode(Kind.one, forKey: .kind)
                try container.encode(childId, forKey: .value)
            case .many(let childIds):
                try container.encode(Kind.many, forKey: .kind)
                try container.encode(childIds, forKey: .value)
            }
        }

    }

    let id: ID
    let parentType: ContentTypeId
    let parentId: ParentId
    let fieldName: FieldName
    let children: Children

    var localeCode: LocaleCode {
        Self.localeCode(for: children)
    }

    init(parentType: ContentTypeId, parentId: ParentId, fieldName: FieldName, childId: RelationshipChildId) {
        self.init(parentType: parentType, parentId: parentId, fieldName: fieldName, children: .one(childId))
    }

    init(parentType: ContentTypeId, parentId: ParentId, fieldName: FieldName, childIds: [RelationshipChildId]) {
        self.init(parentType: parentType, parentId: parentId, fieldName: fieldName, children: .many(childIds))
    }

    private init(parentType: ContentTypeId, parentId: ParentId, fieldName: FieldName, children: Children) {
        self.parentType = parentType
        self.parentId = parentId
        self.fieldName = fieldName
        self.children = children
        self.id = [parentType, parentId, fieldName, Self.localeCode(for: children) ?? "-"].joined(separator: ",")
    }

    private static func localeCode(for children: Children) -> LocaleCode {
        switch children {
        case .one(let childId):
            return childId.localeCode
        case .many(let childIds):
            return childIds.first?.localeCode
        }
    }

}
