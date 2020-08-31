//
//  ContentfulPersistence
//

@testable import ContentfulPersistence
import XCTest

class ToOneRelationshipTests: XCTestCase {

    func testRelationship() {
        let relationship = ToOneRelationship(
            parentType: "1",
            parentId: "2",
            fieldName: "3",
            childId: .init(value: "4")
        )

        XCTAssertEqual(relationship.type, RelationshipType.toOne)
    }
}
