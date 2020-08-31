//
//  ContentfulPersistence
//

/// Represents one-to-one between two elements.
struct ToOneRelationship: Codable, Equatable {

    let type: RelationshipType = .toOne

    /// `EntryPersistable.contentTypeId`
    var parentType: String

    var parentId: String
    let fieldName: String
    var childId: RelationshipChildId
}
