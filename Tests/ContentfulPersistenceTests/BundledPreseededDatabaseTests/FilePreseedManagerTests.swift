//
//  FilePreseedManagerTests.swift
//  ContentfulPersistenceTests
//

import XCTest
@testable import ContentfulPersistence

class FilePreseedManagerTests: XCTestCase {

    // MARK: - Mocks

    /// A mock `SyncSpacePersistable` to simulate stored objects with a `dbVersion`.
    class MockSyncSpace: SyncSpacePersistable {
        var syncToken: String?
        var dbVersion: NSNumber?

        init(dbVersion: Int?) {
            if let version = dbVersion {
                self.dbVersion = NSNumber(value: version)
            } else {
                self.dbVersion = nil
            }
        }
    }

    /// A mock `PersistenceStore` that records calls to the preseed hooks and controls `fetchAll` behavior.
    class MockPersistenceStore: PersistenceStore {
        // Simulate the array returned by `fetchAll(type:predicate:)`.
        var spacesToReturn: [MockSyncSpace] = []
        var fetchAllCalled = false

        // Record URLs passed to preseed hooks
        private(set) var willBeginURL: URL?
        private(set) var completedURL: URL?
        var willBeginCalled = false
        var completedCalled = false

        // Optionally simulate a fetch error
        var fetchError: Error?

        func create<T>(type: Any.Type) throws -> T {
            fatalError("Not needed for preseed tests")
        }

        func delete(type: Any.Type, predicate: NSPredicate) throws {
            fatalError("Not needed for preseed tests")
        }

        func fetchAll<T>(type: Any.Type, predicate: NSPredicate) throws -> [T] {
            fetchAllCalled = true
            if let error = fetchError {
                throw error
            }
            // Force‐cast: our tests always call fetchAll with T = MockSyncSpace
            return spacesToReturn as! [T]
        }

        func fetchOne<T>(type: Any.Type, predicate: NSPredicate) throws -> T {
            fatalError("Not needed for preseed tests")
        }

        func properties(for type: Any.Type) throws -> [String] {
            fatalError("Not needed for preseed tests")
        }

        func relationships(for type: Any.Type) throws -> [String] {
            fatalError("Not needed for preseed tests")
        }

        func save() throws {
            fatalError("Not needed for preseed tests")
        }

        func wipe() throws {
            fatalError("Not needed for preseed tests")
        }

        func performBlock(block: @escaping () -> Void) {
            block()
        }

        func performAndWait(block: @escaping () -> Void) {
            block()
        }

        func onStorePreseedingWillBegin(at storeFileURL: URL) throws {
            willBeginCalled = true
            willBeginURL = storeFileURL
        }

        func onStorePreseedingCompleted(at seededFileURL: URL) throws {
            completedCalled = true
            completedURL = seededFileURL
        }
    }

    /// A mock `FileManaging` that simulates file existence, removal, directory creation, and copying.
    class MockFileManager: FileManaging {
        // Control responses for `fileExists(atPath:)`
        var existingPaths: Set<String> = []
        func fileExists(atPath path: String) -> Bool {
            return existingPaths.contains(path)
        }

        // Record calls and optionally throw
        private(set) var removeItemCalled = false
        private(set) var removeItemURL: URL?
        var removeItemError: Error?

        func removeItem(at url: URL) throws {
            removeItemCalled = true
            removeItemURL = url
            if let error = removeItemError {
                throw error
            }
        }

        private(set) var createDirectoryCalled = false
        private(set) var createdDirectoryURL: URL?
        var createDirectoryError: Error?

        func createDirectory(at url: URL,
                             withIntermediateDirectories createIntermediates: Bool,
                             attributes: [FileAttributeKey : Any]?) throws {
            createDirectoryCalled = true
            createdDirectoryURL = url
            if let error = createDirectoryError {
                throw error
            }
        }

        private(set) var copyItemCalled = false
        private(set) var copySourceURL: URL?
        private(set) var copyDestinationURL: URL?
        var copyItemError: Error?

        func copyItem(at src: URL, to dst: URL) throws {
            copyItemCalled = true
            copySourceURL = src
            copyDestinationURL = dst
            if let error = copyItemError {
                throw error
            }
        }
    }

    // MARK: - Helpers

    /// Creates a temporary directory and returns its URL. Asserts no error.
    private func makeTemporaryDirectory() -> URL {
        let tempDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDirURL,
                                                 withIntermediateDirectories: true,
                                                 attributes: nil)
        return tempDirURL
    }

    /// Creates a “mock bundle” by creating a directory at `bundleURL` with a file named `<name>.<ext>`.
    /// Returns a `Bundle` pointed at that directory. Asserts no error.
    private func makeBundle(containingResourceNamed resourceName: String,
                            withExtension resourceExtension: String) -> (bundle: Bundle, resourceURL: URL) {
        let bundleDir = makeTemporaryDirectory()
        // Place a dummy seed file in that directory
        let resourceFilename = "\(resourceName).\(resourceExtension)"
        let resourceURL = bundleDir.appendingPathComponent(resourceFilename)
        // Write an empty file there
        FileManager.default.createFile(atPath: resourceURL.path, contents: Data(), attributes: nil)
        // Create a Bundle pointing to that directory
        guard let bundle = Bundle(path: bundleDir.path) else {
            fatalError("Could not create test bundle at \(bundleDir.path)")
        }
        return (bundle: bundle, resourceURL: resourceURL)
    }

    // MARK: - Tests

    func testHappyPath_whenDBDoesNotExistAndNoExistingVersion_seedsSuccessfully() throws {
        // Arrange
        let mockStore = MockPersistenceStore()
        // No existing spaces: lastVersion = 0
        mockStore.spacesToReturn = []
        let mockFileManager = MockFileManager()
        // Simulate file not existing at target path
        // (we’ll calculate dbURL below and ensure it is not in `existingPaths`)

        // Create a mock “bundle” containing SeedDB.sqlite
        let resourceName = "SeedDB"
        let resourceExtension = "sqlite"
        let (bundle, seedURL) = makeBundle(containingResourceNamed: resourceName,
                                            withExtension: resourceExtension)

        // Create a temporary directory to act as the sqliteContainerPath
        let containerDir = makeTemporaryDirectory()
        let dbURL = containerDir.appendingPathComponent("\(resourceName).\(resourceExtension)")
        XCTAssertFalse(mockFileManager.fileExists(atPath: dbURL.path),
                       "Precondition: DB file should not exist yet")

        // Build the configuration with dbVersion = 1
        let config = PreseedConfiguration(resourceName: resourceName,
                                          resourceExtension: resourceExtension,
                                          subdirectory: nil,
                                          bundle: bundle,
                                          sqliteContainerPath: containerDir,
                                          dbVersion: 1)

        let strategy = FilePreseedManager(fileManager: mockFileManager)

        // Act
        try strategy.apply(to: mockStore, with: config, spaceType: MockSyncSpace.self)

        // Assert: fetchAll was called to determine lastVersion
        XCTAssertTrue(mockStore.fetchAllCalled, "fetchAll should be called to read existing dbVersion")
        // onStorePreseedingWillBegin and onStorePreseedingCompleted should have been called with dbURL
        XCTAssertTrue(mockStore.willBeginCalled, "Should call onStorePreseedingWillBegin")
        XCTAssertEqual(mockStore.willBeginURL, dbURL, "Will-begin URL should match target DB URL")
        XCTAssertTrue(mockStore.completedCalled, "Should call onStorePreseedingCompleted")
        XCTAssertEqual(mockStore.completedURL, dbURL, "Completed URL should match target DB URL")
        // fileManager should have wiped (removeItem) the folder
        XCTAssertTrue(mockFileManager.removeItemCalled, "Should attempt to remove existing container directory")
        XCTAssertEqual(mockFileManager.removeItemURL, containerDir,
                       "removeItem should be called on the sqliteContainerPath")
        // directory creation should have been called on the same container path
        XCTAssertTrue(mockFileManager.createDirectoryCalled, "Should create container directory")
        XCTAssertEqual(mockFileManager.createdDirectoryURL, containerDir,
                       "createDirectory should target the sqliteContainerPath")
        // copyItem should be called from seedURL to dbURL
        XCTAssertTrue(mockFileManager.copyItemCalled, "Should copy seed file to target location")
        XCTAssertEqual(mockFileManager.copySourceURL, seedURL,
                       "copyItem source should be the seed file in the bundle")
        XCTAssertEqual(mockFileManager.copyDestinationURL, dbURL,
                       "copyItem destination should be the dbURL in the container directory")
    }

    func testNoOp_whenDBExistsAndVersionNotBumped_doesNothing() throws {
        // Arrange
        let mockStore = MockPersistenceStore()
        // Simulate existing object with dbVersion = 1
        mockStore.spacesToReturn = [MockSyncSpace(dbVersion: 1)]
        let mockFileManager = MockFileManager()

        // Create the target db file path and tell fileManager it exists
        let resourceName = "SeedDB"
        let resourceExtension = "sqlite"
        let containerDir = makeTemporaryDirectory()
        let dbURL = containerDir.appendingPathComponent("\(resourceName).\(resourceExtension)")
        mockFileManager.existingPaths.insert(dbURL.path)

        // Create a dummy bundle but it should never be used
        let (bundle, _) = makeBundle(containingResourceNamed: resourceName,
                                     withExtension: resourceExtension)

        // Build a config with the same dbVersion = 1
        let config = PreseedConfiguration(resourceName: resourceName,
                                          resourceExtension: resourceExtension,
                                          subdirectory: nil,
                                          bundle: bundle,
                                          sqliteContainerPath: containerDir,
                                          dbVersion: 1)

        let strategy = FilePreseedManager(fileManager: mockFileManager)

        // Act
        try strategy.apply(to: mockStore, with: config, spaceType: MockSyncSpace.self)

        // Assert: since version is not bumped, nothing should be invoked
        XCTAssertTrue(mockStore.fetchAllCalled, "We still check fetchAll once")
        XCTAssertFalse(mockStore.willBeginCalled, "Should not call preseed hooks")
        XCTAssertFalse(mockStore.completedCalled, "Should not call preseed hooks")
        XCTAssertFalse(mockFileManager.removeItemCalled, "Should not remove container")
        XCTAssertFalse(mockFileManager.createDirectoryCalled, "Should not create directory")
        XCTAssertFalse(mockFileManager.copyItemCalled, "Should not copy any file")
    }

    func testVersionBump_whenDBExistsButNewVersion_seedsSuccessfully() throws {
        // Arrange
        let mockStore = MockPersistenceStore()
        // Simulate existing object with dbVersion = 1
        mockStore.spacesToReturn = [MockSyncSpace(dbVersion: 1)]
        let mockFileManager = MockFileManager()

        // Simulate existing file so fileExists returns true
        let resourceName = "SeedDB"
        let resourceExtension = "sqlite"
        let containerDir = makeTemporaryDirectory()
        let dbURL = containerDir.appendingPathComponent("\(resourceName).\(resourceExtension)")
        mockFileManager.existingPaths.insert(dbURL.path)

        // Create a bundle with a seed file
        let (bundle, seedURL) = makeBundle(containingResourceNamed: resourceName,
                                            withExtension: resourceExtension)

        // Build a config with bumped dbVersion = 2
        let config = PreseedConfiguration(resourceName: resourceName,
                                          resourceExtension: resourceExtension,
                                          subdirectory: nil,
                                          bundle: bundle,
                                          sqliteContainerPath: containerDir,
                                          dbVersion: 2)

        let strategy = FilePreseedManager(fileManager: mockFileManager)

        // Act
        try strategy.apply(to: mockStore, with: config, spaceType: MockSyncSpace.self)

        // Assert: preseed path should be executed same as happy path
        XCTAssertTrue(mockStore.fetchAllCalled, "fetchAll must be called")
        XCTAssertTrue(mockStore.willBeginCalled, "onStorePreseedingWillBegin should be called for version bump")
        XCTAssertTrue(mockStore.completedCalled, "onStorePreseedingCompleted should be called for version bump")
        XCTAssertTrue(mockFileManager.removeItemCalled, "Should remove existing container directory")
        XCTAssertTrue(mockFileManager.createDirectoryCalled, "Should recreate container directory")
        XCTAssertTrue(mockFileManager.copyItemCalled, "Should copy seed file into container")
        XCTAssertEqual(mockFileManager.copySourceURL, seedURL, "Copy source must be the seed URL")
        XCTAssertEqual(mockFileManager.copyDestinationURL, dbURL, "Copy destination must be the dbURL")
    }

    func testRemoveItemError_isIgnoredAndContinues() throws {
        // Arrange
        let mockStore = MockPersistenceStore()
        mockStore.spacesToReturn = [] // lastVersion = 0
        let mockFileManager = MockFileManager()
        mockFileManager.removeItemError = NSError(domain: "Test", code: 999, userInfo: nil)

        // DB does not exist initially
        let resourceName = "SeedDB"
        let resourceExtension = "sqlite"
        let (bundle, seedURL) = makeBundle(containingResourceNamed: resourceName,
                                            withExtension: resourceExtension)
        let containerDir = makeTemporaryDirectory()
        let dbURL = containerDir.appendingPathComponent("\(resourceName).\(resourceExtension)")

        // fileExists returns false by default
        let config = PreseedConfiguration(resourceName: resourceName,
                                          resourceExtension: resourceExtension,
                                          subdirectory: nil,
                                          bundle: bundle,
                                          sqliteContainerPath: containerDir,
                                          dbVersion: 1)
        let strategy = FilePreseedManager(fileManager: mockFileManager)

        // Act & Assert: even though removeItem throws, apply should complete without throwing
        XCTAssertNoThrow(try strategy.apply(to: mockStore, with: config, spaceType: MockSyncSpace.self),
                         "Errors thrown by removeItem(at:) should be ignored")
        // The rest of the operations after removal ought to be recorded
        XCTAssertTrue(mockFileManager.removeItemCalled, "removeItem must be attempted")
        XCTAssertTrue(mockFileManager.createDirectoryCalled, "createDirectory must still be called")
        XCTAssertTrue(mockFileManager.copyItemCalled, "copyItem must still be called")
        XCTAssertTrue(mockStore.willBeginCalled, "onStorePreseedingWillBegin must be called")
        XCTAssertTrue(mockStore.completedCalled, "onStorePreseedingCompleted must be called")
        XCTAssertEqual(mockFileManager.copySourceURL, seedURL, "copy source must match seedURL")
        XCTAssertEqual(mockFileManager.copyDestinationURL, dbURL, "copy destination must match dbURL")
    }

    func testSeedFileMissing_throwsError() throws {
        // Arrange
        let mockStore = MockPersistenceStore()
        mockStore.spacesToReturn = [] // lastVersion = 0
        let mockFileManager = MockFileManager()

        // Create a bundle directory WITHOUT placing the seed file inside
        let bundleDir = makeTemporaryDirectory()
        // No file named "MissingDB.sqlite" inside
        guard let bundle = Bundle(path: bundleDir.path) else {
            XCTFail("Could not create bundle for test")
            return
        }

        let resourceName = "MissingDB"
        let resourceExtension = "sqlite"
        let containerDir = makeTemporaryDirectory()

        let config = PreseedConfiguration(resourceName: resourceName,
                                          resourceExtension: resourceExtension,
                                          subdirectory: nil,
                                          bundle: bundle,
                                          sqliteContainerPath: containerDir,
                                          dbVersion: 1)
        let strategy = FilePreseedManager(fileManager: mockFileManager)

        // Act & Assert: apply should throw NSError with the expected domain and code
        XCTAssertThrowsError(try strategy.apply(to: mockStore, with: config, spaceType: MockSyncSpace.self)) { error in
            guard let nsError = error as NSError? else {
                return XCTFail("Expected NSError, got \(type(of: error))")
            }
            XCTAssertEqual(nsError.domain, "ContentfulPersistence", "Error domain should match")
            XCTAssertEqual(nsError.code, 1, "Error code should be 1 when seed file missing")
            XCTAssertTrue(nsError.localizedDescription.contains("\(resourceName).\(resourceExtension)"),
                          "Error message should mention the missing resource name and extension")
        }
        // No preseed hooks should be invoked
        XCTAssertFalse(mockStore.willBeginCalled, "onStorePreseedingWillBegin should not be called on missing seed")
        XCTAssertFalse(mockStore.completedCalled, "onStorePreseedingCompleted should not be called on missing seed")
        // No directory or copy operations should happen
        XCTAssertFalse(mockFileManager.removeItemCalled, "removeItem should not occur when seed missing")
        XCTAssertFalse(mockFileManager.createDirectoryCalled, "createDirectory should not occur when seed missing")
        XCTAssertFalse(mockFileManager.copyItemCalled, "copyItem should not occur when seed missing")
    }

    func testFetchAllError_treatedAsVersionZero() throws {
        // Arrange
        let mockStore = MockPersistenceStore()
        // Simulate fetchAll throwing an error
        mockStore.fetchError = NSError(domain: "TestFetchError", code: -1, userInfo: nil)
        let mockFileManager = MockFileManager()

        // Create a bundle with a seed file
        let resourceName = "SeedDB"
        let resourceExtension = "sqlite"
        let (bundle, seedURL) = makeBundle(containingResourceNamed: resourceName,
                                            withExtension: resourceExtension)

        let containerDir = makeTemporaryDirectory()
        let dbURL = containerDir.appendingPathComponent("\(resourceName).\(resourceExtension)")

        // fileExists returns false by default
        let config = PreseedConfiguration(resourceName: resourceName,
                                          resourceExtension: resourceExtension,
                                          subdirectory: nil,
                                          bundle: bundle,
                                          sqliteContainerPath: containerDir,
                                          dbVersion: 1)
        let strategy = FilePreseedManager(fileManager: mockFileManager)

        // Act: Should complete successfully, treating lastVersion = 0
        XCTAssertNoThrow(try strategy.apply(to: mockStore, with: config, spaceType: MockSyncSpace.self),
                         "fetchAll error should be caught and treated as version = 0")
        // onStorePreseedingWillBegin and onStorePreseedingCompleted should be called
        XCTAssertTrue(mockStore.willBeginCalled, "onStorePreseedingWillBegin must be called if fetchAll errors")
        XCTAssertTrue(mockStore.completedCalled, "onStorePreseedingCompleted must be called if fetchAll errors")
        // file operations should have occurred
        XCTAssertTrue(mockFileManager.removeItemCalled, "Should attempt to remove container directory on fetchAll error")
        XCTAssertTrue(mockFileManager.createDirectoryCalled, "Should create directory on fetchAll error")
        XCTAssertTrue(mockFileManager.copyItemCalled, "Should copy seed file on fetchAll error")
        XCTAssertEqual(mockFileManager.copySourceURL, seedURL, "copy source must match seedURL")
        XCTAssertEqual(mockFileManager.copyDestinationURL, dbURL, "copy destination must match dbURL")
    }
}
