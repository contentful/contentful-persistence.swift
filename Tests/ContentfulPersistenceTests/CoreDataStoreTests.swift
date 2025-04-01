//
//  CoreDataStoreTests.swift
//  ContentfulPersistence
//
//  Created by Marius Kurgonas on 01/04/2025.
//  Copyright © 2025 Contentful GmbH. All rights reserved.
//

import XCTest
import CoreData
@testable import ContentfulPersistence

// MARK: - Test NSManagedObject subclass

public class TestEntity: NSManagedObject {
    @NSManaged public var value: String
}

// MARK: - CoreDataStore Unit Tests

class CoreDataStoreTests: XCTestCase {
    
    var temporaryDirectory: URL!
    var model: NSManagedObjectModel!
    
    override func setUp() {
        super.setUp()
        
        // Create a unique temporary directory for our store files.
        temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Create an NSManagedObjectModel programmatically with one entity: TestEntity.
        let testEntity = NSEntityDescription()
        testEntity.name = "TestEntity"
        testEntity.managedObjectClassName = NSStringFromClass(TestEntity.self)
        
        let valueAttribute = NSAttributeDescription()
        valueAttribute.name = "value"
        valueAttribute.attributeType = .stringAttributeType
        valueAttribute.isOptional = false
        
        testEntity.properties = [valueAttribute]
        
        model = NSManagedObjectModel()
        model.entities = [testEntity]
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        super.tearDown()
    }
    
    // Helper to create a URL for a store file in our temporary directory.
    func storeURL(fileName: String) -> URL {
        return temporaryDirectory.appendingPathComponent(fileName)
    }
    
    // Create a managed object context with a persistent store at a given URL.
    func createManagedObjectContext(storeURL: URL) throws -> NSManagedObjectContext {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSSQLiteStoreType,
                                            configurationName: nil,
                                            at: storeURL,
                                            options: nil)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }
    
    // Create an empty persistent store file (simulate a bundled database) at the given URL.
    func createEmptyBundledStore(at url: URL) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        // Adding a persistent store creates the file on disk.
        try coordinator.addPersistentStore(ofType: NSSQLiteStoreType,
                                            configurationName: nil,
                                            at: url,
                                            options: nil)
    }
    
    func testCoreDataStoreReplacement() throws {
        // Step 1: Setup core data store on disk.
        let originalStoreURL = storeURL(fileName: "OriginalStore.sqlite")
        let context = try createManagedObjectContext(storeURL: originalStoreURL)
        let coreDataStore = CoreDataStore(context: context)
        
        // Step 2: Write one simple object to database.
        let testObject: TestEntity = try coreDataStore.create(type: TestEntity.self)
        testObject.value = "original"
        try coreDataStore.save()
        
        // Step 3: Read the value ensuring it persisted.
        let fetchAllPredicate = NSPredicate(value: true)
        let fetched: [TestEntity] = try coreDataStore.fetchAll(type: TestEntity.self, predicate: fetchAllPredicate)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.value, "original")
        
        // Step 4: Prepare a bundled store file (simulate another bundled db that is empty).
        let bundledStoreURL = storeURL(fileName: "BundledStore.sqlite")
        try createEmptyBundledStore(at: bundledStoreURL)
        
        // Step 5: Replace the current store with the bundled one.
        try coreDataStore.replaceStoreWithBundledDatabase(url: bundledStoreURL)
        
        // After replacement, fetching should return no objects.
        let fetchedAfterReplacement: [TestEntity] = try coreDataStore.fetchAll(type: TestEntity.self, predicate: fetchAllPredicate)
        XCTAssertEqual(fetchedAfterReplacement.count, 0)
        
        // Step 6: Write and then read the same object again.
        let newObject: TestEntity = try coreDataStore.create(type: TestEntity.self)
        newObject.value = "new"
        try coreDataStore.save()
        
        let fetchedNew: [TestEntity] = try coreDataStore.fetchAll(type: TestEntity.self, predicate: fetchAllPredicate)
        XCTAssertEqual(fetchedNew.count, 1)
        XCTAssertEqual(fetchedNew.first?.value, "new")
    }
}
