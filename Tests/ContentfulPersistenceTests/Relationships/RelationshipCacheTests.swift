//
//  ContentfulPersistence
//

@testable import ContentfulPersistence
import XCTest

class RelationshipCacheTests: XCTestCase {

    func test_relationships_areCachedOnDisk() {
        let fileName = makeFileName()
        let cache = RelationshipCache(cacheFileName: fileName)

        XCTAssertEqual(cache.relationships.count, 0)

        cache.add(relationship: makeToOne1())
        cache.add(relationship: makeToOne2())
        cache.add(relationship: makeToMany1())

        cache.save()

        // Verify
        let verifyCache = RelationshipCache(cacheFileName: fileName)

        verifyCache.add(relationship: makeToOne1(localeCode: "en-US"))

        XCTAssertEqual(verifyCache.relationships.count, 4)
    }

    func test_relationship_isDeleted() {
        let fileName = makeFileName()
        let cache = RelationshipCache(cacheFileName: fileName)

        XCTAssertEqual(cache.relationships.count, 0)

        cache.add(relationship: makeToOne1())

        let toOne2 = makeToOne2()
        cache.add(relationship: toOne2)

        let toMany1 = makeToMany1()
        cache.add(relationship: toMany1)

        XCTAssertEqual(cache.relationships.count, 3)

        cache.delete(parentId: toOne2.parentId)
        XCTAssertEqual(cache.relationships.count, 2)

        cache.delete(parentId: toMany1.parentId)
        XCTAssertEqual(cache.relationships.count, 1)

        cache.add(relationship: toOne2)
        cache.add(relationship: toMany1)

        cache.delete(
            parentId: toOne2.parentId,
            fieldName: toOne2.fieldName,
            localeCode: toOne2.localeCode
        )

        XCTAssertEqual(cache.relationships.count, 2)

        cache.delete(
            parentId: toMany1.parentId,
            fieldName: toMany1.fieldName,
            localeCode: toMany1.localeCode
        )

        XCTAssertEqual(cache.relationships.count, 1)
    }

    func test_deleteRelationship_byLocale() {
        let fileName = makeFileName()
        let cache = RelationshipCache(cacheFileName: fileName)

        XCTAssertEqual(cache.relationships.count, 0)

        let toOne1a = makeToOne1(localeCode: "en-US")
        let toOne1b = makeToOne1(localeCode: "pl-PL")
        cache.add(relationship: toOne1a)
        cache.add(relationship: toOne1b)

        cache.delete(
            parentId: toOne1a.parentId,
            fieldName: toOne1a.fieldName,
            localeCode: nil
        )

        XCTAssertEqual(cache.relationships.count, 2)

        cache.delete(
            parentId: toOne1a.parentId,
            fieldName: toOne1a.fieldName,
            localeCode: "en-GB"
        )

        XCTAssertEqual(cache.relationships.count, 2)

        cache.delete(
            parentId: toOne1a.parentId,
            fieldName: toOne1a.fieldName,
            localeCode: toOne1a.localeCode
        )

        XCTAssertEqual(cache.relationships.count, 1)

        cache.delete(
            parentId: toOne1b.parentId,
            fieldName: toOne1b.fieldName,
            localeCode: toOne1b.localeCode
        )

        XCTAssertEqual(cache.relationships.count, 0)
    }

    private func makeToOne1(localeCode: String? = nil) -> Relationship {
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

    private func makeToOne2() -> Relationship {
        .init(
            parentType: "person",
            parentId: "person-2",
            fieldName: "cat",
            childId: .init(value: "cat-1")
        )
    }

    private func makeToMany1() -> Relationship {
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
