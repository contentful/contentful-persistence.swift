//
//  FilePreseedManagerTests.swift
//  ContentfulPersistenceTests
//

import XCTest
@testable import ContentfulPersistence
import CoreData

class FakeSyncSpacePersistable: SyncSpacePersistable {
    var syncToken: String?
    var dbVersion: NSNumber?
}

class FakeStore: PersistenceStore {
    var beginURL: URL?
    var completedURL: URL?
    var savedSpace = FakeSyncSpacePersistable()

    func create<T>(type: Any.Type) throws -> T { fatalError() }
    func delete(type: Any.Type, predicate: NSPredicate) throws {}
    func fetchAll<T>(type: Any.Type, predicate: NSPredicate) throws -> [T] { [] }
    func fetchOne<T>(type: Any.Type, predicate: NSPredicate) throws -> T {
        guard let s = savedSpace as? T else { fatalError() }
        return s
    }
    func properties(for type: Any.Type) throws -> [String] { [] }
    func relationships(for type: Any.Type) throws -> [String] { [] }
    func save() throws {}
    func wipe() throws {}
    func performBlock(block: @escaping () -> Void) { block() }
    func performAndWait(block: @escaping () -> Void) { block() }

    func onStorePreseedingWillBegin(at storeFileURL: URL) throws {
        beginURL = storeFileURL
    }
    func onStorePreseedingCompleted(at seededFileURL: URL) throws {
        completedURL = seededFileURL
    }
}

class FakeFileManager: FileManaging {
    var existingPaths = Set<String>()
    var removed = [URL]()
    var created = [URL]()
    var copied  = [(src: URL, dst: URL)]()

    func fileExists(atPath path: String) -> Bool {
        existingPaths.contains(path)
    }
    func removeItem(at url: URL) throws {
        removed.append(url)
        existingPaths.remove(url.path)
    }
    func createDirectory(at url: URL, withIntermediateDirectories: Bool, attributes: [FileAttributeKey: Any]?) throws {
        created.append(url)
        existingPaths.insert(url.path)
    }
    func copyItem(at src: URL, to dst: URL) throws {
        copied.append((src, dst))
        existingPaths.insert(dst.path)
    }
}

class FilePreseedManagerTests: XCTestCase {
    var fm: FakeFileManager!
    var store: FakeStore!
    var mgr: FilePreseedManager!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        fm = FakeFileManager()
        store = FakeStore()
        mgr = FilePreseedManager(fileManager: fm)
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
                   .appendingPathComponent(UUID().uuidString)
    }

    func testFreshInstall_wipesFolderAndCopiesSeed_andCallsStoreHooks() throws {
        let bundleDir = tempDir.appendingPathComponent("Bundle")
        try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)
        let seed = bundleDir.appendingPathComponent("Test.sqlite")
        FileManager.default.createFile(atPath: seed.path, contents: Data([0x01]))

        let testBundle = Bundle(path: bundleDir.path)!
        fm.existingPaths = []  // no DB yet

        let config = PreseedConfiguration(
            resourceName: "Test",
            resourceExtension: "sqlite",
            subdirectory: nil,
            bundle: testBundle,
            sqliteContainerPath: tempDir,
            dbVersion: 5
        )

        try mgr.apply(to: store, with: config, spaceType: FakeSyncSpacePersistable.self)

        XCTAssertEqual(store.beginURL, tempDir.appendingPathComponent("Test.sqlite"))
        XCTAssertTrue(fm.removed.contains(tempDir))
        XCTAssertTrue(fm.created.contains(tempDir))
        XCTAssertEqual(fm.copied.first?.src.path, seed.path)
        XCTAssertEqual(store.completedURL, tempDir.appendingPathComponent("Test.sqlite"))
        XCTAssertEqual(store.savedSpace.dbVersion?.intValue, 5)
    }

    func testNoInstall_whenVersionUnchanged_doesNothing() throws {
        let dbURL = tempDir.appendingPathComponent("Test.sqlite")
        fm.existingPaths = [dbURL.path]
        store.savedSpace.dbVersion = NSNumber(value: 10)

        let bundleDir = tempDir.appendingPathComponent("Bundle2")
        try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: bundleDir.appendingPathComponent("Test.sqlite").path, contents: Data())
        let testBundle = Bundle(path: bundleDir.path)!

        let config = PreseedConfiguration(
            resourceName: "Test",
            resourceExtension: "sqlite",
            subdirectory: nil,
            bundle: testBundle,
            sqliteContainerPath: tempDir,
            dbVersion: 10
        )

        try mgr.apply(to: store, with: config, spaceType: FakeSyncSpacePersistable.self)

        XCTAssertNil(store.beginURL)
        XCTAssertTrue(fm.removed.isEmpty)
        XCTAssertTrue(fm.copied.isEmpty)
        XCTAssertNil(store.completedURL)
    }
}
