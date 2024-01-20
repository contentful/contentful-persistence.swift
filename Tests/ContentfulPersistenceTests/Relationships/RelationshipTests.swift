//
//  ContentfulPersistence
//

@testable import ContentfulPersistence
import XCTest

class RelationshipTests: XCTestCase {

    func testInitWithOneChild() {
        let child1 = RelationshipChildId(id: "child1", localeCode: nil)
        let relationship = Relationship(
            parentType: "parentType",
            parentId: "parentId",
            fieldName: "fieldName",
            childId: child1
        )

        XCTAssertEqual(relationship.children, .one(child1))
    }

    func testInitWithManyChildren() {
        let child1 = RelationshipChildId(id: "child1", localeCode: nil)
        let child2 = RelationshipChildId(id: "child2", localeCode: nil)
        let child3 = RelationshipChildId(id: "child3", localeCode: nil)
        let relationship = Relationship(
            parentType: "parentType",
            parentId: "parentId",
            fieldName: "fieldName",
            childIds: [child1, child2, child3]
        )

        XCTAssertEqual(relationship.children, .many([child1, child2, child3]))
    }

}
