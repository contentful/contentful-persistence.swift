//
//  ContentfulPersistence
//

/// Represents one-to-many relationship between two entries.
struct ToManyRelationship: Codable, Equatable {

    let type: RelationshipType = .toMany

    /// `EntryPersistable.contentTypeId`
    var parentType: String

    var parentId: String
    let fieldName: String
    var childIds: [RelationshipChildId]
}
