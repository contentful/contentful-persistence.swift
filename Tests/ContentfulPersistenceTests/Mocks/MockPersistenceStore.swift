import Foundation

@testable import ContentfulPersistence

class MockPersistenceStore: PersistenceStore {

    var returnValue: Any?

    func create<T>(type: any Any.Type) throws -> T {
        if let returnValue = returnValue as? T {
            return returnValue
        } else {
            fatalError(
                "MockPersistenceStore.create was called without a return value being set."
            )
        }
    }

    func delete(type _: any Any.Type, predicate _: NSPredicate) throws {}

    func fetchAll<T>(type _: any Any.Type, predicate _: NSPredicate) throws
        -> [T]
    {
        []
    }

    func fetchOne<T>(type: any Any.Type, predicate _: NSPredicate) throws -> T {
        if let returnValue = returnValue as? T {
            return returnValue
        } else {
            fatalError(
                "MockPersistenceStore.create was called without a return value being set."
            )
        }
    }

    func properties(for _: any Any.Type) throws -> [String] {
        []
    }

    func relationships(for _: any Any.Type) throws -> [String] {
        []
    }

    func save() throws {}

    func wipe() throws {}

    func performBlock(block: @escaping () -> Void) {
        block()
    }

    func performAndWait(block: @escaping () -> Void) {
        block()
    }
}
