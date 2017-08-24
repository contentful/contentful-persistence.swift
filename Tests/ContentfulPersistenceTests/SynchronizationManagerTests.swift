//
//  ContentfulPersistenceTests.swift
//  ContentfulPersistenceTests
//
//  Created by Boris Bügling on 30/03/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

@testable import ContentfulPersistence
import Contentful
import Interstellar
import ObjectMapper
import XCTest
import Nimble
import CoreData
import CoreLocation

typealias TestFunc = (() -> ()) throws -> ()

class ContentfulPersistenceTests: XCTestCase {

    let assetPredicate = NSPredicate(format: "id == 'bXvdSYHB3Guy2uUmuEco8'")
    let postPredicate = NSPredicate(format: "id == '1asN98Ph3mUiCYIYiiqwko'")

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

    func postTests(expectations: @escaping TestFunc) {
        let expectation = self.expectation(description: "PostTests expectation")

        self.client.initialSync() { result in
            expect(result.value).toNot(beNil())

            self.managedObjectContext.perform {
                do {
                    let posts: [Post] = try self.store.fetchAll(type: Post.self, predicate: NSPredicate(value: true))
                    expect(posts.count).to(equal(2))
                    expectation.fulfill()
                } catch {
                    fail("Fetching posts should not throw an error")
                }
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testPropertyMappingInferredCorrectly() {
        // We must have a space first to pass in locale information.
        let spaceMap = Map(mappingType: .fromJSON, JSON: TestHelpers.jsonData("space"))
        let space = try! Space(map: spaceMap)

        let localesContext = space.localizationContext

        let map = Map(mappingType: .fromJSON, JSON: TestHelpers.jsonData("single-author"), context: localesContext)
        let author = try! Entry(map: map)

        let expectedPropertyMapping: [FieldName: String] = [
            "name": "name",
            "website": "website",
            "biography": "biography"
        ]
        let authorPropertyMapping = syncManager.propertyMapping(for: Author.self, and: author.fields)
        expect(authorPropertyMapping).to(equal(expectedPropertyMapping))
    }

    func testRelationshipMappingInferredCorrectly() {
        // We must have a space first to pass in locale information.
        let spaceMap = Map(mappingType: .fromJSON, JSON: TestHelpers.jsonData("space"))
        let space = try! Space(map: spaceMap)

        let localesContext = space.localizationContext

        let map = Map(mappingType: .fromJSON, JSON: TestHelpers.jsonData("single-author"), context: localesContext)
        let author = try! Entry(map: map)

        let expectedRelationshipMapping: [FieldName: String] = [
            "createdEntries": "createdEntries",
            "profilePhoto": "profilePhoto"
        ]
        let authorRelationshipMapping = syncManager.relationshipMapping(for: Author.self, and: author.fields)
        expect(authorRelationshipMapping).to(equal(expectedRelationshipMapping))
    }

    func testSyncManagerCanStoreSyncTokens() {
        let expectation = self.expectation(description: "Can store sync tokens")

        self.client.initialSync() { result in
            self.managedObjectContext.perform {
                expect(result.value!.assets.count).to(beGreaterThan(0))
                expect(self.syncManager.syncToken?.characters.count).to(beGreaterThan(0))

                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testCanContinueSyncWithExistingToken() {
        let expectation = self.expectation(description: "Can continue sync")

        let syncSpace = SyncSpace(syncToken: "w5ZGw6JFwqZmVcKsE8Kow4grw45QdybDqXt4XTFdw6tcwrMiwqpmwq7DlcOqZ8KnwpUiG1sZwr3Cq8OpFcKEUsOyPcOiQMOEITLDnyIkw4fDq8KAw6x_Mh3Dui_Cgw3CnsKswrwhw6hNwostejQDw4nDmUkp")

        self.client.nextSync(for: syncSpace) { result in
            expect(result.value!.entries.count).to(equal(0))
            expectation.fulfill()
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func canStoreAssetPersistables() {
        let expectation = self.expectation(description: "Can store Asset Persistables expecatation")

        self.client.initialSync() { result in

            self.managedObjectContext.perform {
                do {
                    let assets: [Asset] = try self.store.fetchAll(type: Asset.self, predicate: NSPredicate(value: true))
                    expect(assets.count).to(equal(6))

                    let alice: Asset? = try! self.store.fetchAll(type: Asset.self, predicate: self.assetPredicate).first
                    expect(alice).toNot(beNil())
                    expect(alice?.title).to(equal("Alice in Wonderland"))
                    expect(alice?.urlString).to(equal("https://images.contentful.com/dqpnpm0n4e75/bXvdSYHB3Guy2uUmuEco8/608761ef6c0ef23815b410d5629208f9/alice-in-wonderland.gif"))
                } catch {
                    XCTAssert(false, "Fetching asset(s) should not throw an error")
                }
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func canStoreEntryPersistables() {
        self.postTests { done in
            let post: Post? = try! self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
            expect(post).toNot(beNil())
            expect(post?.title).to(equal("Down the Rabbit Hole"))

            done()
        }
    }

    func canMapContentfulAssetLinksAsCoreDataRelationships() {

        self.postTests { done in
            let post: Post? = try self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
            expect(post).toNot(beNil())
            expect(post?.theFeaturedImage).toNot(beNil())
            expect(post?.theFeaturedImage?.urlString).toNot(beNil())
            expect(post?.theFeaturedImage?.urlString).to(equal("https://images.contentful.com/dqpnpm0n4e75/bXvdSYHB3Guy2uUmuEco8/608761ef6c0ef23815b410d5629208f9/alice-in-wonderland.gif"))

            done()
        }
    }


    func canMapContentfulEntryLinksAsCoreDataRelationshiops() {

        self.postTests { done in
            let post: Post? = try self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
            expect(post).toNot(beNil())

            expect(post?.authors).toNot(beNil())
            expect(post?.authors?.count).to(equal(1))
            guard let author = post?.authors?.firstObject as? Author else {
                fail("was unable to make relationship")
                done()
                return
            }
            expect(author.name).toNot(beNil())
            expect(author.name).to(equal("Lewis Carroll"))
            done()
        }
    }

    func testRespectsMappingsWhenCreatingCoreDataEntities() {
        self.postTests { done in
            let post: Post? = try self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
            expect(post).toNot(beNil())
            expect(post?.comments).to(beNil())
            expect(post?.title).toNot(beNil())
            expect(post?.theFeaturedImage).toNot(beNil())
            done()
        }
    }

    func testCanDetermineCoreDataProperties() {
        let store = CoreDataStore(context: self.managedObjectContext)

        do {
            let properties = try store.properties(for: Category.self)

            expect(Set(properties)).to(equal(Set(["title", "id", "createdAt", "updatedAt", "localeCode"])))
        } catch {
            fail("Storing properties for Categories should not throw an error")
        }
    }

    func canDetermineCoreDataRelationships() {
        let store = CoreDataStore(context: self.managedObjectContext)

        do {
            let relationships = try store.relationships(for: Post.self)
            let expectedRelationships = Set(["authors", "theFeaturedImage", "category"])
            expect(Set(relationships)).to(equal(expectedRelationships))
        } catch {
            XCTAssert(false, "Storing relationships for Posts should not throw an error")
        }
    }
}
