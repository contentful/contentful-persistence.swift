//
//  ContentfulPersistence
//

/// Represents one-to-many relationship between two entries.
struct ToManyRelationship: Codable, Equatable, Hashable {
    typealias Id = String
    let id: Id
    let type: RelationshipType

    /// `EntryPersistable.contentTypeId`
    let parentType: String

    let parentId: String
    let fieldName: String
    let childIds: [RelationshipChildId]
    
    internal init(parentType: String, parentId: String, fieldName: String, childIds: [RelationshipChildId]) {
        self.parentType = parentType
        self.parentId = parentId
        self.fieldName = fieldName
        self.childIds = childIds
        self.id = ([parentType, parentId, fieldName, childIds.first?.localeCode ?? "-"] + childIds.map { $0.id }.sorted()).joined(separator: ",")
        self.type = .toMany
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
