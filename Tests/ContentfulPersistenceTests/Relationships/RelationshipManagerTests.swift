//
//  ContentfulPersistence
//

import Contentful
@testable import ContentfulPersistence
import XCTest

class RelationshipManagerTests: XCTestCase {

    func test_manager_worksCorrectly() {
        let manager = RelationshipsManager(cacheFileName: makeFileName())

        let entry1 = EntryA(id: "person-1")

        for _ in 0..<5 {
            manager.cacheToOneRelationship(
                parent: entry1,
                childId: RelationshipChildId(rawValue: "dog-1"),
                fieldName: "dog"
            )
        }

        XCTAssertEqual(manager.relationships.count, 1)

        let entry2 = EntryA(id: "person-2")

        for _ in 0..<5 {
            manager.cacheToOneRelationship(
                parent: entry2,
                childId: RelationshipChildId(rawValue: "dog-1"),
                fieldName: "dog"
            )
        }

        XCTAssertEqual(manager.relationships.count, 2)

        for _ in 0..<5 {
            manager.cacheToManyRelationship(
                parent: entry1,
                childIds: [
                    RelationshipChildId(rawValue: "cat-1"),
                    RelationshipChildId(rawValue: "cat-2"),
                    RelationshipChildId(rawValue: "cat-3")
                ],
                fieldName: "cats"
            )
        }

        XCTAssertEqual(manager.relationships.count, 3)

        manager.delete(parentId: entry1.id, fieldName: "cats", localeCode: nil)
        XCTAssertEqual(manager.relationships.count, 2)

        manager.delete(parentId: entry2.id)
        XCTAssertEqual(manager.relationships.count, 1)

        manager.delete(parentId: entry1.id)
        XCTAssertEqual(manager.relationships.count, 0)
    }

    func testStaleToOneRelationshipsAreRemoved() {
        let manager = RelationshipsManager(cacheFileName: makeFileName())

        let entry1 = EntryA(id: "person-1")
        let dog1 = RelationshipChildId(rawValue: "dog-1")
        let dog2 = RelationshipChildId(rawValue: "dog-2")

        manager.cacheToOneRelationship(
            parent: entry1,
            childId: dog1,
            fieldName: "dog"
        )

        XCTAssertNotNil(manager.relationships.relationships(for: dog1))

        manager.cacheToOneRelationship(
            parent: entry1,
            childId: dog2,
            fieldName: "dog"
        )

        XCTAssertTrue(manager.relationships.relationships(for: dog1).isEmpty)
        XCTAssertFalse(manager.relationships.relationships(for: dog2).isEmpty)
    }

    func testStaleToManyRelationshipsAreRemoved() {
        let manager = RelationshipsManager(cacheFileName: makeFileName())

        let entry1 = EntryA(id: "person-1")
        let cat1 = RelationshipChildId(rawValue: "cat-1")
        let cat2 = RelationshipChildId(rawValue: "cat-2")
        let cat3 = RelationshipChildId(rawValue: "cat-3")
        let cat4 = RelationshipChildId(rawValue: "cat-4")

        manager.cacheToManyRelationship(
            parent: entry1,
            childIds: [
                cat1,
                cat2,
                cat3
            ],
            fieldName: "cats"
        )

        XCTAssertFalse(manager.relationships.relationships(for: cat1).isEmpty)
        XCTAssertFalse(manager.relationships.relationships(for: cat2).isEmpty)
        XCTAssertFalse(manager.relationships.relationships(for: cat3).isEmpty)

        manager.cacheToManyRelationship(
            parent: entry1,
            childIds: [
                cat1,
                cat2,
                cat4
            ],
            fieldName: "cats"
        )

        XCTAssertFalse(manager.relationships.relationships(for: cat1).isEmpty)
        XCTAssertFalse(manager.relationships.relationships(for: cat2).isEmpty)
        XCTAssertTrue(manager.relationships.relationships(for: cat3).isEmpty)
        XCTAssertFalse(manager.relationships.relationships(for: cat4).isEmpty)
    }

    private func makeFileName() -> String {
        UUID().uuidString + "-\(Date().timeIntervalSince1970)"
    }
}

private class EntryA: NSObject, EntryPersistable {

    static var contentTypeId: ContentTypeId = "entry-a"

    static func fieldMapping() -> [FieldName : String] {
        [:]
    }

    var id: String
    var localeCode: String?
    var updatedAt: Date? = nil
    var createdAt: Date? = nil

    init(id: String = "", localeCode: String? = nil) {
        self.id = id
        self.localeCode = localeCode
    }
}
