//
//  ContentfulPersistenceSwift
//

enum Relationship: Codable {

    private enum CodingKeys: CodingKey {
        case type
    }

    enum Error: Swift.Error {
        case invalidRelationship
    }

    case toOne(ToOneRelationship)
    case toMany(ToManyRelationship)

    func value<T>() -> T? {
        switch self {
        case .toOne(let relationship):
            return relationship as? T
        case .toMany(let relationship):
            return relationship as? T
        }
    }

    // MARK: Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)

        switch RelationshipType(rawValue: typeString) {
        case .toOne:
            self = try .toOne(ToOneRelationship(from: decoder))
        case .toMany:
            self = try .toMany(ToManyRelationship(from: decoder))
        case .none:
            throw Error.invalidRelationship
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .toOne(let relationship):
            try relationship.encode(to: encoder)
        case .toMany(let relationship):
            try relationship.encode(to: encoder)
        }
    }
}


enum RelationshipType: String, Codable {
    case toOne
    case toMany
}
