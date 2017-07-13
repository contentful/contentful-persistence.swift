//
//  ContentfulPersistenceTestBase.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 30/03/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

import CoreData
import Nimble
import Quick

class ContentfulPersistenceTestBase: QuickSpec {
    let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last?.appendingPathComponent("Test.sqlite")

    func deleteCoreDataStore() {
        guard FileManager.default.fileExists(atPath: self.storeURL!.absoluteString) == true else { return }

        try! FileManager.default.removeItem(at: self.storeURL!)
        try! FileManager.default.removeItem(at: append("-shm", to: self.storeURL!))
        try! FileManager.default.removeItem(at: append("-wal", to: self.storeURL!))
    }

    lazy var managedObjectContext: NSManagedObjectContext = {
        let modelURL = Bundle(for: type(of: self)).url(forResource: "Test", withExtension: "momd")
        let mom = NSManagedObjectModel(contentsOf: modelURL!)
        expect(mom).toNot(beNil())

        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom!)

        do {
            var store = try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: self.storeURL!, options: nil)
            expect(store).toNot(beNil())
        } catch {
            XCTAssert(false, "Recreating the persistent store SQL files should not throw an error")
        }

        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = psc
        return managedObjectContext
    }()

    func append(_ string: String, to fileURL: URL) -> URL {
        let pathString = fileURL.path.appending(string)
        return URL(fileURLWithPath: pathString)
    }
}
