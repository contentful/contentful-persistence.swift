//
//  ContentfulPersistence
//

/// Represents one-to-one between two elements.
struct ToOneRelationship: Codable, Equatable, Identifiable, Hashable {
    typealias Id = String
    let id: Id    
    let type: RelationshipType

    /// `EntryPersistable.contentTypeId`
    let parentType: String

    let parentId: String
    let fieldName: String
    let childId: RelationshipChildId
    
    internal init(parentType: String, parentId: String, fieldName: String, childId: RelationshipChildId) {
        self.parentType = parentType
        self.parentId = parentId
        self.fieldName = fieldName
        self.childId = childId
        self.id = [parentType, parentId, fieldName, childId.id, childId.localeCode ?? "-"].joined(separator: ",")
        self.type = .toOne
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
