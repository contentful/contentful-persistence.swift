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
import XCTest
import Nimble
import CoreData
import CoreLocation

class ContentfulPersistenceTests: XCTestCase {

    let assetPredicate = NSPredicate(format: "id == 'bXvdSYHB3Guy2uUmuEco8'")
    let postPredicate = NSPredicate(format: "id == '1asN98Ph3mUiCYIYiiqwko'")

    lazy var managedObjectContext: NSManagedObjectContext = {
        return TestHelpers.managedObjectContext(forMOMInTestBundleNamed: "Test")
    }()
    
    var client: Client!

    lazy var store: CoreDataStore = {
        return CoreDataStore(context: self.managedObjectContext)
    }()

    var syncManager: SynchronizationManager!

    override func setUp() {
        let entryTypes: [EntryPersistable.Type] = [Author.self, Category.self, Post.self]

        let persistenceModel = PersistenceModel(spaceType: SyncInfo.self, assetType: Asset.self, entryTypes: entryTypes)

        let synchronizationManager = SynchronizationManager(localizationScheme: .default, persistenceStore: self.store, persistenceModel: persistenceModel)

        self.client = Client(spaceId: "dqpnpm0n4e75",
                             accessToken: "95c33f933385aa838825526c5753f3b5a7e59bb45cd6b5d78e15bfeafeef1b13",
                             persistenceIntegration: synchronizationManager)

        self.syncManager = synchronizationManager
    }

    func testPropertyMappingInferredCorrectly() {
        // We must have a space first to pass in locale information.
        let spaceData = TestHelpers.jsonData("space")
        let jsonDecoder = JSONDecoder.withoutLocalizationContext()
        let space = try! jsonDecoder.decode(Space.self, from: spaceData)
        jsonDecoder.update(with: LocalizationContext(locales: space.locales)!)
        let authorData = TestHelpers.jsonData("single-author")

        let author = try! jsonDecoder.decode(Entry.self, from: authorData)

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
        let spaceData = TestHelpers.jsonData("space")
        let jsonDecoder = JSONDecoder.withoutLocalizationContext()
        let space = try! jsonDecoder.decode(Space.self, from: spaceData)
        jsonDecoder.update(with: LocalizationContext(locales: space.locales)!)
        let authorData = TestHelpers.jsonData("single-author")

        let author = try! jsonDecoder.decode(Entry.self, from: authorData)

        let expectedRelationshipMapping: [FieldName: String] = [
            "createdEntries": "createdEntries",
            "profilePhoto": "profilePhoto"
        ]
        let authorRelationshipMapping = syncManager.relationshipMapping(for: Author.self, and: author.fields)
        expect(authorRelationshipMapping).to(equal(expectedRelationshipMapping))
    }

    func testSyncManagerCanStoreSyncTokens() {
        let expectation = self.expectation(description: "Can store sync tokens")

        self.client.sync { result in
            self.managedObjectContext.perform {
                expect(result.value!.assets.count).to(beGreaterThan(0))
                expect(self.syncManager.syncToken?.count).to(beGreaterThan(0))

                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testCanContinueSyncWithExistingToken() {
        let expectation = self.expectation(description: "Can continue sync")

        let syncSpace = SyncSpace(syncToken: "w5ZGw6JFwqZmVcKsE8Kow4grw45QdybDqXt4XTFdw6tcwrMiwqpmwq7DlcOqZ8KnwpUiG1sZwr3Cq8OpFcKEUsOyPcOiQMOEITLDnyIkw4fDq8KAw6x_Mh3Dui_Cgw3CnsKswrwhw6hNwostejQDw4nDmUkp")

        self.client.sync(for: syncSpace) { result in
            expect(result.value!.entries.count).to(equal(0))
            expectation.fulfill()
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testCanStoreAssetPersistables() {
        let expectation = self.expectation(description: "Can store Asset Persistables expecatation")

        self.client.sync { result in

            self.managedObjectContext.perform {
                do {
                    let assets: [Asset] = try self.store.fetchAll(type: Asset.self, predicate: NSPredicate(value: true))
                    expect(assets.count).to(equal(6))

                    let alice: Asset? = try! self.store.fetchAll(type: Asset.self, predicate: self.assetPredicate).first
                    expect(alice).toNot(beNil())
                    expect(alice?.title).to(equal("Alice in Wonderland"))
                    expect(alice?.urlString).to(equal("https://images.ctfassets.net/dqpnpm0n4e75/bXvdSYHB3Guy2uUmuEco8/608761ef6c0ef23815b410d5629208f9/alice-in-wonderland.gif"))
                    expect(alice?.width).to(equal(644))
                    expect(alice?.height).to(equal(610))
                    expect(alice?.size).to(equal(24238))
                    expect(alice?.fileName).to(equal("alice-in-wonderland.gif"))
                    expect(alice?.fileType).to(equal("image/gif"))
                    self.client.fetchData(for: alice!).then { data in
                        XCTAssert(true)
                        expectation.fulfill()
                    }.error { error in
                        fail("Data fetch should have succeed \(error)")
                        expectation.fulfill()
                    }
                } catch {
                    XCTAssert(false, "Fetching asset(s) should not throw an error")
                }
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testStoringEntryPersistables() {

        let expectation = self.expectation(description: "")

        self.client.sync { result in
            expect(result.value).toNot(beNil())

            self.managedObjectContext.perform {
                do {
                    let post: Post? = try self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
                    expect(post).toNot(beNil())
                    expect(post?.title).to(equal("Down the Rabbit Hole"))
                    expectation.fulfill()
                } catch {
                    fail("Fetching posts should not throw an error")
                    fail("Fetching posts should not throw an error")
                }
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testMappingContentfulAssetLinksAsCoreDataRelationships() {
        let expectation = self.expectation(description: "")

        self.client.sync { result in
            expect(result.value).toNot(beNil())

            self.managedObjectContext.perform {
                do {
                    let post: Post? = try self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
                    expect(post).toNot(beNil())
                    expect(post?.theFeaturedImage).toNot(beNil())
                    expect(post?.theFeaturedImage?.urlString).toNot(beNil())
                    expect(post?.theFeaturedImage?.urlString).to(equal("https://images.ctfassets.net/dqpnpm0n4e75/bXvdSYHB3Guy2uUmuEco8/608761ef6c0ef23815b410d5629208f9/alice-in-wonderland.gif"))
                    expectation.fulfill()
                } catch {
                    fail("Fetching posts should not throw an error")
                }
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testResolvingLinkedEntriesArray() {
        let expectation = self.expectation(description: "")

        self.client.sync { result in
            expect(result.value).toNot(beNil())

            self.managedObjectContext.perform {
                do {
                    let post: Post? = try self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
                    expect(post).toNot(beNil())

                    expect(post?.authors).toNot(beNil())
                    expect(post?.authors?.count).to(equal(1))
                    guard let author = post?.authors?.firstObject as? Author else {
                        fail("was unable to make relationship")
                        expectation.fulfill()
                        return
                    }
                    expect(author.name).toNot(beNil())
                    expect(author.name).to(equal("Lewis Carroll"))
                    expectation.fulfill()
                } catch {
                    fail("Fetching posts should not throw an error")
                    fail("Fetching posts should not throw an error")
                }
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testRespectsMappingsWhenCreatingCoreDataEntities() {

        let expectation = self.expectation(description: "")

        self.client.sync { result in
            expect(result.value).toNot(beNil())

            self.managedObjectContext.perform {
                do {
                    let post: Post? = try self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
                    expect(post).toNot(beNil())
                    expect(post?.comments).to(beNil())
                    expect(post?.title).toNot(beNil())
                    expect(post?.theFeaturedImage).toNot(beNil())
                    expectation.fulfill()
                } catch {
                    fail("Fetching posts should not throw an error")
                    fail("Fetching posts should not throw an error")
                }
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
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
