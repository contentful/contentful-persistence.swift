//
//  TestHelpers.swift
//  ContentfulPersistence
//
//  Created by JP Wright on 12.07.17.
//  Copyright © 2017 Contentful GmbH. All rights reserved.
//

import Foundation
import CoreData
import Nimble
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
        expect(mom).toNot(beNil())

        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom!)

        do {
            // Store in memory so there is no caching between test methods.
            let store = try psc.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
            expect(store).toNot(beNil())
        } catch {
            XCTAssert(false, "Recreating the persistent store SQL files should not throw an error")
        }

        let managedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = psc
        return managedObjectContext
    }
}
