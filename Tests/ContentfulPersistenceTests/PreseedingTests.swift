//
//  File.swift
//  ContentfulPersistence
//
//  Created by JP Wright on 06.09.17.
//  Copyright © 2017 Contentful GmbH. All rights reserved.
//


@testable import ContentfulPersistence
import Contentful
import Interstellar
import ObjectMapper
import XCTest
import Nimble
import CoreData
import CoreLocation

class PreseededDatabaseTests: XCTestCase {

    #if os(iOS) || os(macOS)
    let storeURL = FileManager.default.urls(for: .documentDirectory,
                                            in: .userDomainMask).last?.appendingPathComponent("Test.sqlite")
    #elseif os(tvOS)
    let storeURL = FileManager.default.urls(for: .cachesDirectory,
    in: .userDomainMask).last?.appendingPathComponent("Test.sqlite")
    #endif

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

    var client: Client!

    lazy var store: CoreDataStore = {
        return CoreDataStore(context: self.managedObjectContext)
    }()

    var syncManager: SynchronizationManager!

    override func setUp() {
        let entryTypes: [EntryPersistable.Type] = [Author.self, Category.self, Post.self]

        let persistenceModel = PersistenceModel(spaceType: SyncInfo.self, assetType: Asset.self, entryTypes: entryTypes)

        let synchronizationManager = SynchronizationManager(localizationScheme: .default, persistenceStore: self.store, persistenceModel: persistenceModel)

        self.client = Client(spaceId: "dqpnpm0n4e75", accessToken: "95c33f933385aa838825526c5753f3b5a7e59bb45cd6b5d78e15bfeafeef1b13", persistenceIntegration: synchronizationManager)
        self.syncManager = synchronizationManager

        self.deleteCoreDataStore()
    }

    let postPredicate = NSPredicate(format: "id == '1asN98Ph3mUiCYIYiiqwko'")

    func testsCanPreseedDBAndMapLinksToCoreDataRelationships() {
        let directoryName = "PreseedJSONFiles"
        let testBundle = Bundle(for: type(of: self))

        try! syncManager.seedDBFromJSONFiles(in: directoryName, in: testBundle)

        let post: Post? = try! self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
        expect(post).toNot(beNil())

        expect(post?.authors).toNot(beNil())
        expect(post?.authors?.count).to(equal(1))
        guard let author = post?.authors?.firstObject as? Author else {
            fail("was unable to make relationship")
            return
        }
        expect(author.name).toNot(beNil())
        expect(author.name).to(equal("Lewis Carroll"))

        let assets: [Asset] = try! self.store.fetchAll(type: Asset.self, predicate: NSPredicate(value: true))
        expect(assets.count).to(equal(6))

        for asset in assets {
            let assetData = SynchronizationManager.bundledData(for: asset, inDirectoryNamed: directoryName, in: testBundle)
            expect(assetData).toNot(beNil())
        }
    }

    func testsPreseedDBFromMultipageBundleContainsAllEntriesAndAssets() {

        let directoryName = "MultifilePreseedJSONFiles"
        let testBundle = Bundle(for: type(of: self))
        try! syncManager.seedDBFromJSONFiles(in: directoryName, in: testBundle)

        let posts: [Post] = try! self.store.fetchAll(type: Post.self, predicate: NSPredicate(value: true))
        expect(posts.count).to(equal(2))

        let authors: [Author] = try! self.store.fetchAll(type: Author.self, predicate: NSPredicate(value: true))
        expect(authors.count).to(equal(2))

        let categories: [Category] = try! self.store.fetchAll(type: Category.self, predicate: NSPredicate(value: true))
        expect(categories.count).to(equal(2))
    }
}
