@testable import ContentfulPersistence
import Foundation

class MockSyncSpacePersistable: SyncSpacePersistable {
    var syncToken: String? = nil
    var dbVersion: NSNumber? = nil
}
