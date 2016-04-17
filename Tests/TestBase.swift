//
//  ContentfulPersistenceTestBase.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 30/03/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

import CatchingFire
import CoreData
import Nimble
import Quick

class ContentfulPersistenceTestBase: QuickSpec {
    let storeURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).last?.URLByAppendingPathComponent("Test.sqlite")

    lazy var managedObjectContext: NSManagedObjectContext = {
        let modelURL = NSBundle(forClass: self.dynamicType).URLForResource("Test", withExtension: "momd")
        let mom = NSManagedObjectModel(contentsOfURL: modelURL!)
        expect(mom).toNot(beNil())

        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom!)

        AssertNoThrow {
            try NSFileManager.defaultManager().removeItemAtURL(self.storeURL!)
            var store = try psc.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: self.storeURL!, options: nil)
            expect(store).toNot(beNil())
        }

        var managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = psc
        return managedObjectContext
    }()
    
}
