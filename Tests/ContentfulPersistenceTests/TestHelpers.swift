//
//  TestHelpers.swift
//  ContentfulPersistence
//
//  Created by JP Wright on 12.07.17.
//  Copyright © 2017 Contentful GmbH. All rights reserved.
//

import Foundation
import CoreData
import XCTest

class TestHelpers {

    static func jsonData(_ fileName: String) -> Data {
        let bundle = Bundle(for: TestHelpers.self)
        let urlPath = bundle.path(forResource: fileName, ofType: "json")!
        return try! Data(contentsOf: URL(fileURLWithPath: urlPath))
    }
    
    static func managedObjectContext(forMOMInTestBundleNamed momName: String) -> NSManagedObjectContext {
        let modelURL = Bundle(for: TestHelpers.self).url(forResource: momName, withExtension: "momd")
        let mom = NSManagedObjectModel(contentsOf: modelURL!)
        XCTAssertNotNil(mom)

        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom!)

        do {
            // Store in memory so there is no caching between test methods.
            let store = try psc.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
            XCTAssertNotNil(store)
        } catch {
            XCTAssert(false, "Recreating the persistent store SQL files should not throw an error")
        }

        let managedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = psc
        return managedObjectContext
    }
    
    /// Spins up a file-backed Core Data stack for testing.
    ///
    /// - Parameter momName: The `.momd` name in your test bundle.
    /// - Returns: A tuple `(context, sqliteURL)` where `context` is
    ///   an `NSManagedObjectContext` backed by the sqlite at `sqliteURL`.
    static func sqliteBackedContext(forMOMInTestBundleNamed momName: String)
        throws
    -> (context: NSManagedObjectContext, sqliteURL: URL, storeContainerPath: URL)
    {
        let bundle   = Bundle(for: TestHelpers.self)
        guard
            let modelURL = bundle.url(forResource: momName, withExtension: "momd"),
            let mom      = NSManagedObjectModel(contentsOf: modelURL)
        else {
            XCTFail("Couldn’t load model \(momName).momd from test bundle")
            fatalError()
        }

        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = psc

        // Create a unique temp directory for the sqlite file
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let sqliteURL = tempDir.appendingPathComponent("\(momName).sqlite")
        do {
            let store = try psc.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: sqliteURL,
                options: nil
            )
            XCTAssertNotNil(store, "Failed to add SQLite store at \(sqliteURL)")
        } catch {
            XCTFail("Error adding SQLite store: \(error)")
        }
        
        return (context, sqliteURL, tempDir)
    }
}
