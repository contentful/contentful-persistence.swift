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

    private func makeToOne1(localeCode: String? = nil) -> ToOneRelationship {
        var childId = "dog-1"
        if let localeCode = localeCode {
            childId += "_\(localeCode)"
        }

        return .init(
            parentType: "person",
            parentId: "person-1",
            fieldName: "dog",
            childId: .init(value: childId)
        )
    }

    private func makeToOne2() -> ToOneRelationship {
        .init(
            parentType: "person",
            parentId: "person-2",
            fieldName: "cat",
            childId: .init(value: "cat-1")
        )
    }

    private func makeToMany1() -> ToManyRelationship {
        .init(
            parentType: "person",
            parentId: "person-3",
            fieldName: "things",
            childIds: [
                .init(value: "cat-1"),
                .init(value: "dog-2")
            ]
        )
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
