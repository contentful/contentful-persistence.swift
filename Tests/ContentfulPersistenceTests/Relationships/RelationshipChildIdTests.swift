//
//  ContentfulPersistence
//

@testable import ContentfulPersistence
import XCTest

class RelationshipChildIdTests: XCTestCase {

    func test_idAndLocale_areSet() {
        let id = "abc-def"
        let localeCode = "en-US"

        let value = "\(id)_\(localeCode)"

        let childId = RelationshipChildId(rawValue: value)
        XCTAssertEqual(childId.id, id)
        XCTAssertEqual(childId.localeCode, localeCode)
    }

    func test_id_isSet() {
        let id = "abc-def"

        let childId = RelationshipChildId(rawValue: id)
        XCTAssertEqual(childId.id, id)
        XCTAssertNil(childId.localeCode)
    }
}
