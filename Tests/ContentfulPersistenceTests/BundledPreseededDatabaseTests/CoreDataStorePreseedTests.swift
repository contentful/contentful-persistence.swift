//
//  CoreDataStorePreseedTests.swift
//  ContentfulPersistence
//
//  Created by Marius Kurgonas on 30/05/2025.
//  Copyright © 2025 Contentful GmbH. All rights reserved.
//

import XCTest
@testable import ContentfulPersistence
import CoreData

class CoreDataStorePreseedTests: XCTestCase {
    var ctx: NSManagedObjectContext!
    var store: CoreDataStore!
    var sqliteURL: URL!
    var syncManager: SynchronizationManager!

    override func setUpWithError() throws {
        // Obtain a file-backed Core Data stack and its SQLite URL:
        let data = try TestHelpers.sqliteBackedContext(
            forMOMInTestBundleNamed: "Test"
        )
        ctx = data.context
        sqliteURL = data.sqliteURL

        store = CoreDataStore(context: ctx)
        
        let entryTypes: [EntryPersistable.Type] = [Author.self, Category.self, Post.self]
        
        let persistenceModel = PersistenceModel(spaceType: SyncInfo.self, assetType: Asset.self, entryTypes: entryTypes)
        
        syncManager = SynchronizationManager(localizationScheme: .default, persistenceStore: store, persistenceModel: persistenceModel)
    }

    func testWillBegin_removesSideCarsAndStore() throws {
        let directoryName = "PreseedJSONFiles"
        let testBundle = Bundle(for: Swift.type(of: self))
        do {
            try syncManager.seedDBFromJSONFiles(in: directoryName, in: testBundle)
        } catch let error {
            XCTFail(error.localizedDescription)
        }
        
        // At this point Core Data should have created:
        //   <sqliteURL>.sqlite-wal  and  <sqliteURL>.sqlite-shm
        let wal = URL(fileURLWithPath: sqliteURL.path + "-wal")
        let shm = URL(fileURLWithPath: sqliteURL.path + "-shm")
        XCTAssertTrue(FileManager.default.fileExists(atPath: wal.path),
                      "WAL file should exist after saving.")
        XCTAssertTrue(FileManager.default.fileExists(atPath: shm.path),
                      "SHM file should exist after saving.")
        XCTAssertEqual(ctx.persistentStoreCoordinator?.persistentStores.count, 1,
                       "There should be exactly one persistent store before wiping.")

        // 2) Call the hook under test:
        try store.onStorePreseedingWillBegin(at: sqliteURL)

        // 3) Verify WAL and SHM have been deleted:
        XCTAssertFalse(FileManager.default.fileExists(atPath: wal.path),
                       "WAL must be removed by onStorePreseedingWillBegin.")
        XCTAssertFalse(FileManager.default.fileExists(atPath: shm.path),
                       "SHM must be removed by onStorePreseedingWillBegin.")

        // 4) Verify the persistent store was removed from the coordinator:
        XCTAssertEqual(ctx.persistentStoreCoordinator?.persistentStores.count, 0,
                       "Persistent store should be removed by onStorePreseedingWillBegin.")
    }

    func testCompleted_readdsStoreAndResetsContext() throws {
        // First remove the store so the coordinator is empty:
        try store.onStorePreseedingWillBegin(at: sqliteURL)
        XCTAssertEqual(ctx.persistentStoreCoordinator?.persistentStores.count, 0,
                       "Store should be gone after onStorePreseedingWillBegin.")

        // Now re-open the store and reset the context:
        try store.onStorePreseedingCompleted(at: sqliteURL)

        // Verify the store was re-added:
        XCTAssertEqual(ctx.persistentStoreCoordinator?.persistentStores.count, 1,
                       "Persistent store should be re-added by onStorePreseedingCompleted.")

        // Verify the context was reset (no remaining registered objects):
        XCTAssertTrue(ctx.registeredObjects.isEmpty,
                      "Context must be reset after onStorePreseedingCompleted.")
    }
}
