@testable import ContentfulPersistence
import Foundation

class MockPersistenceStore: PersistenceStore {
    func create<T>(type _: any Any.Type) throws -> T {
        fatalError()
    }

    func delete(type _: any Any.Type, predicate _: NSPredicate) throws {}

    func fetchAll<T>(type _: any Any.Type, predicate _: NSPredicate) throws -> [T] {
        []
    }

    func fetchOne<T>(type _: any Any.Type, predicate _: NSPredicate) throws -> T {
        fatalError()
    }

    func properties(for _: any Any.Type) throws -> [String] {
        []
    }

    func relationships(for _: any Any.Type) throws -> [String] {
        []
    }

    func save() throws {}

    func wipe() throws {}

    func performBlock(block _: @escaping () -> Void) {}

    func performAndWait(block _: @escaping () -> Void) {}
}
