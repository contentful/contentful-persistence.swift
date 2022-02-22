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
                childId: "dog-1",
                fieldName: "dog"
            )
        }

        XCTAssertEqual(manager.relationships.count, 1)

        let entry2 = EntryA(id: "person-2")

        for _ in 0..<5 {
            manager.cacheToOneRelationship(
                parent: entry2,
                childId: "dog-1",
                fieldName: "dog"
            )
        }

        XCTAssertEqual(manager.relationships.count, 2)

        for _ in 0..<5 {
            manager.cacheToManyRelationship(
                parent: entry1,
                childIds: [
                    "cat-1",
                    "cat-2",
                    "cat-3"
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
        manager.cacheToOneRelationship(
            parent: entry1,
            childId: "dog-1",
            fieldName: "dog"
        )

        XCTAssertNotNil(manager.relationships.relationships(for: "dog-1", with: nil))

        manager.cacheToOneRelationship(
            parent: entry1,
            childId: "dog-2",
            fieldName: "dog"
        )

        XCTAssertTrue(manager.relationships.relationships(for: "dog-1", with: nil).isEmpty)
        XCTAssertFalse(manager.relationships.relationships(for: "dog-2", with: nil).isEmpty)
    }

    func testStaleToManyRelationshipsAreRemoved() {
        let manager = RelationshipsManager(cacheFileName: makeFileName())

        let entry1 = EntryA(id: "person-1")
        manager.cacheToManyRelationship(
            parent: entry1,
            childIds: [
                "cat-1",
                "cat-2",
                "cat-3"
            ],
            fieldName: "cats"
        )

        XCTAssertFalse(manager.relationships.relationships(for: "cat-1", with: nil).isEmpty)
        XCTAssertFalse(manager.relationships.relationships(for: "cat-2", with: nil).isEmpty)
        XCTAssertFalse(manager.relationships.relationships(for: "cat-3", with: nil).isEmpty)

        manager.cacheToManyRelationship(
            parent: entry1,
            childIds: [
                "cat-1",
                "cat-2",
                "cat-4"
            ],
            fieldName: "cats"
        )

        XCTAssertFalse(manager.relationships.relationships(for: "cat-1", with: nil).isEmpty)
        XCTAssertFalse(manager.relationships.relationships(for: "cat-2", with: nil).isEmpty)
        XCTAssertTrue(manager.relationships.relationships(for: "cat-3", with: nil).isEmpty)
        XCTAssertFalse(manager.relationships.relationships(for: "cat-4", with: nil).isEmpty)
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
