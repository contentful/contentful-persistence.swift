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

class PreseedingDatabaseTests: XCTestCase {
    var ctx: NSManagedObjectContext!
    var store: CoreDataStore!
    var sqliteURL: URL!
    var syncManager: SynchronizationManager!
    var persistenceModel: PersistenceModel!
    var storeContainerPath: URL!

    override func setUpWithError() throws {
        // Obtain a file-backed Core Data stack and its SQLite URL:
        let data = try TestHelpers.sqliteBackedContext(
            forMOMInTestBundleNamed: "Test"
        )
        ctx = data.context
        sqliteURL = data.sqliteURL
        storeContainerPath = data.storeContainerPath
        
        store = CoreDataStore(context: ctx)
        
        let entryTypes: [EntryPersistable.Type] = [Author.self, Category.self, Post.self]
        
        persistenceModel = PersistenceModel(spaceType: SyncInfo.self, assetType: Asset.self, entryTypes: entryTypes)
    }

    func test_synchronizationManager_preseedsDb_whenNoDatabaseInitiallyExists() throws {
        try? FileManager.default.removeItem(atPath: sqliteURL.path)
        
        let version = 10
        let preseedConfig = PreseedConfiguration(resourceName: "Test",
                                                 resourceExtension: "sqlite",
                                                 bundle: Bundle(for: TestHelpers.self),
                                                 sqliteContainerPath: storeContainerPath,
                                                 dbVersion: version)
        // File does not exist yet
        XCTAssertFalse(FileManager.default.fileExists(atPath: sqliteURL.path))
        
        do {
            syncManager = try SynchronizationManager(localizationScheme: .default,
                                                     persistenceStore: store,
                                                     persistenceModel: persistenceModel,
                                                     preseedConfig: preseedConfig)
        } catch (let error) {
            XCTFail(error.localizedDescription)
        }
        
        // File exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: sqliteURL.path))
        
        do {
            let syncInfo: SyncInfo = try store.fetchOne(type: SyncInfo.self,
                                                                    predicate: NSPredicate(value: true))
            XCTAssertEqual(syncInfo.dbVersion!.intValue, version)
        } catch (let error) {
            XCTFail(error.localizedDescription)
        }
    }
    
    func test_synchronizationManager_preseedsDb_whenVersionIsHigher() throws {
        try! FileManager.default.removeItem(atPath: sqliteURL.path)
        try! FileManager.default.copyItem(atPath: Bundle(for: TestHelpers.self).path(forResource: "Test", ofType: "sqlite")!, toPath: sqliteURL.path)
        
        let syncInfo: SyncInfo = try! store.create(type: persistenceModel.spaceType)
        syncInfo.dbVersion = 1
        try! ctx.save()
        ctx.reset()
        let version = 12
        let preseedConfig = PreseedConfiguration(resourceName: "Test",
                                                 resourceExtension: "sqlite",
                                                 bundle: Bundle(for: TestHelpers.self),
                                                 sqliteContainerPath: storeContainerPath,
                                                 dbVersion: version)
        // File exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: sqliteURL.path))
        
        do {
            syncManager = try SynchronizationManager(localizationScheme: .default,
                                                     persistenceStore: store,
                                                     persistenceModel: persistenceModel,
                                                     preseedConfig: preseedConfig)
        } catch (let error) {
            XCTFail(error.localizedDescription)
        }
        
        // File exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: sqliteURL.path))
        
        do {
            let syncInfo: SyncInfo = try store.fetchOne(type: persistenceModel.spaceType,
                                                        predicate: NSPredicate(value: true))
            XCTAssertEqual(syncInfo.dbVersion!.intValue, version)
        } catch (let error) {
            XCTFail(error.localizedDescription)
        }
    }
    
    func test_synchronizationManager_doesNotPreseed_whenVersionIsNotHigher() throws {
        try! FileManager.default.removeItem(atPath: sqliteURL.path)
        try! FileManager.default.copyItem(atPath: Bundle(for: TestHelpers.self).path(forResource: "Test", ofType: "sqlite")!, toPath: sqliteURL.path)
        let version = 11
        let syncInfo: SyncInfo = try! store.create(type: persistenceModel.spaceType)
        syncInfo.dbVersion = NSNumber(integerLiteral: version)
        try! store.save()
        let preseedConfig = PreseedConfiguration(resourceName: "Test",
                                                 resourceExtension: "sqlite",
                                                 bundle: Bundle(for: TestHelpers.self),
                                                 sqliteContainerPath: storeContainerPath,
                                                 dbVersion: version)
        // File exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: sqliteURL.path))
        
        do {
            syncManager = try SynchronizationManager(localizationScheme: .default,
                                                     persistenceStore: store,
                                                     persistenceModel: persistenceModel,
                                                     preseedConfig: preseedConfig)
        } catch (let error) {
            XCTFail(error.localizedDescription)
        }
        
        // File exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: sqliteURL.path))
        
        do {
            let syncInfo: SyncInfo = try store.fetchOne(type: persistenceModel.spaceType,
                                                        predicate: NSPredicate(value: true))
            XCTAssertEqual(syncInfo.dbVersion!.intValue, version)
        } catch (let error) {
            XCTFail(error.localizedDescription)
        }
    }
}
