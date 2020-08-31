//
//  ContentfulPersistence
//

@testable import ContentfulPersistence
import XCTest

class ToManyRelationshipTests: XCTestCase {

    func testRelationship() {
        let relationship = ToManyRelationship(
            parentType: "1",
            parentId: "2",
            fieldName: "3",
            childIds: [.init(value: "4"), .init(value: "5")]
        )

        XCTAssertEqual(relationship.type, RelationshipType.toMany)
    }
}
