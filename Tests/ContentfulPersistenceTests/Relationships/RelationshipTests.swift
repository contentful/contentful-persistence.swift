//
//  ContentfulPersistence
//

@testable import ContentfulPersistence
import XCTest

class RelationshipTests: XCTestCase {

    func testToOneRelationshipValue() {
        let nested = ToOneRelationship(
            parentType: "1",
            parentId: "2",
            fieldName: "3",
            childId: .init(value: "4")
        )

        let relationship = Relationship.toOne(nested)

        let value: ToOneRelationship? = relationship.value()
        XCTAssertEqual(value, nested)
    }

    func testToManyRelationshipValue() {
        let nested = ToManyRelationship(
            parentType: "1",
            parentId: "2",
            fieldName: "3",
            childIds: [.init(value: "4"), .init(value: "5")]
        )

        let relationship = Relationship.toMany(nested)

        let value: ToManyRelationship? = relationship.value()
        XCTAssertEqual(value, nested)
    }
}
