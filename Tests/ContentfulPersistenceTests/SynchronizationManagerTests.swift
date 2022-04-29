//
//  ContentfulPersistenceTests.swift
//  ContentfulPersistenceTests
//
//  Created by Boris Bügling on 30/03/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

@testable import ContentfulPersistence
import Contentful
import XCTest
import CoreData
import CoreLocation

let categoryId = "random id"

class ContentfulPersistenceTests: XCTestCase {

    let assetPredicate = NSPredicate(format: "id == 'bXvdSYHB3Guy2uUmuEco8'")
    let postPredicate = NSPredicate(format: "id == '1asN98Ph3mUiCYIYiiqwko'")
    let categoryPredicate = NSPredicate(format: "id == '\(categoryId)'")

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
        XCTAssertEqual(authorPropertyMapping, expectedPropertyMapping)
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
        XCTAssertEqual(authorRelationshipMapping, expectedRelationshipMapping)
    }

    func testSyncManagerCanStoreSyncTokens() {
        let expectation = self.expectation(description: "Can store sync tokens")

        self.client.sync { result in
            self.managedObjectContext.perform {
                switch result {
                case .success(let space):
                    XCTAssertGreaterThan(space.assets.count, 0)
                    XCTAssertGreaterThan(self.syncManager.syncToken!.count, 0)

                    expectation.fulfill()

                case .failure:
                    XCTFail()
                }
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testCanContinueSyncWithExistingToken() {
        let expectation = self.expectation(description: "Can continue sync")

        let syncSpace = SyncSpace(syncToken: "FEnChMOBwr1Yw4TCqsK2LcKpCH3CjsORI8Oewq4AwrIybcKxaS7DosKAwqPChsKFccO9fsOQDjjCu8KYMcKFwrB6w5NuwoEWwoPDuMO-AVAHNMK6wrcpE8OOwojCo8Oqw7DCvAZ8w7JcAjFlZ1DDui7Dq8KUCMK_JcK2")

        self.client.sync(for: syncSpace) { result in
            switch result {
            case .success(let space):
                XCTAssertEqual(space.entries.count, 0)
                expectation.fulfill()
            case .failure:
                XCTFail()
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testFetchOneAssetFromTheStore() {
        let expectation = self.expectation(description: "Can fetch single asset from the store.")
        self.client.sync { _ in
            let asset: Asset? = try? self.store.fetchOne(type: Asset.self, predicate: self.assetPredicate)
            XCTAssertEqual(asset?.id, "bXvdSYHB3Guy2uUmuEco8")
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
                    XCTAssertEqual(assets.count, 6)

                    let alice: Asset? = try! self.store.fetchAll(type: Asset.self, predicate: self.assetPredicate).first
                    XCTAssertNotNil(alice)
                    XCTAssertEqual(alice?.title, "Alice in Wonderland")
                    XCTAssertEqual(alice?.urlString, "https://images.ctfassets.net/dqpnpm0n4e75/bXvdSYHB3Guy2uUmuEco8/608761ef6c0ef23815b410d5629208f9/alice-in-wonderland.gif")
                    XCTAssertEqual(alice?.width, 644)
                    XCTAssertEqual(alice?.height, 610)
                    XCTAssertEqual(alice?.size, 24238)
                    XCTAssertEqual(alice?.fileName, "alice-in-wonderland.gif")
                    XCTAssertEqual(alice?.fileType, "image/gif")

                    self.client.fetchData(for: alice!) { result in
                        switch result {
                        case .success:
                            XCTAssert(true)
                        case .failure(let error):
                            XCTFail("Data fetch should have succeed \(error)")
                        }
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
            switch result {
            case .success(let space):
                self.managedObjectContext.perform {
                    do {
                        let post: Post? = try self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
                        XCTAssertNotNil(post)
                        XCTAssertEqual(post?.title, "Down the Rabbit Hole")
                        expectation.fulfill()
                    } catch {
                        XCTFail("Fetching posts should not throw an error")
                        XCTFail("Fetching posts should not throw an error")
                    }
                }

            case .failure:
                XCTFail()
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testMappingContentfulAssetLinksAsCoreDataRelationships() {
        let expectation = self.expectation(description: "")

        self.client.sync { [weak self] result in
            switch result {
            case .success:
                guard let self = self else { return }

                self.managedObjectContext.perform {
                    do {
                        let post: Post? = try self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
                        XCTAssertNotNil(post)
                        XCTAssertNotNil(post?.theFeaturedImage)
                        XCTAssertNotNil(post?.theFeaturedImage?.urlString)
                        XCTAssertNotNil(post?.date)
                        XCTAssertEqual(post?.theFeaturedImage?.urlString, "https://images.ctfassets.net/dqpnpm0n4e75/bXvdSYHB3Guy2uUmuEco8/608761ef6c0ef23815b410d5629208f9/alice-in-wonderland.gif")
                        expectation.fulfill()
                    } catch {
                        XCTFail("Fetching posts should not throw an error")
                    }
                }

            case .failure:
                XCTFail()
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testResolvingLinkedEntriesArray() {
        let expectation = self.expectation(description: "")

        self.client.sync { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                self.managedObjectContext.perform {
                    do {
                        let post: Post? = try self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
                        XCTAssertNotNil(post)

                        XCTAssertNotNil(post?.authors)
                        XCTAssertEqual(post?.authors?.count, 1)
                        guard let author = post?.authors?.firstObject as? Author else {
                            XCTFail("was unable to make relationship")
                            expectation.fulfill()
                            return
                        }
                        XCTAssertNotNil(author.name)
                        XCTAssertNotNil(post?.date)
                        XCTAssertEqual(author.name, "Lewis Carroll")
                        expectation.fulfill()
                    } catch {
                        XCTFail("Fetching posts should not throw an error")
                        XCTFail("Fetching posts should not throw an error")
                    }
                }

            case .failure:
                XCTFail()
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testRespectsMappingsWhenCreatingCoreDataEntities() {

        let expectation = self.expectation(description: "")

        self.client.sync { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                self.managedObjectContext.perform {
                    do {
                        let post: Post? = try self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
                        XCTAssertNotNil(post)
                        XCTAssertNil(post?.comments)
                        XCTAssertNotNil(post?.title)
                        XCTAssertNotNil(post?.theFeaturedImage)
                        XCTAssertNotNil(post?.date)
                        expectation.fulfill()
                    } catch {
                        XCTFail("Fetching posts should not throw an error")
                        XCTFail("Fetching posts should not throw an error")
                    }
                }

            case .failure:
                XCTFail()
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testCanDetermineCoreDataProperties() {
        let store = CoreDataStore(context: self.managedObjectContext)

        do {
            let properties = try store.properties(for: Category.self)

            XCTAssertEqual(Set(properties), Set(["title", "id", "createdAt", "updatedAt", "localeCode"]))
        } catch {
            XCTFail("Storing properties for Categories should not throw an error")
        }
    }

    func canDetermineCoreDataRelationships() {
        let store = CoreDataStore(context: self.managedObjectContext)

        do {
            let relationships = try store.relationships(for: Post.self)
            let expectedRelationships = Set(["authors", "theFeaturedImage", "category"])
            XCTAssertEqual(Set(relationships), expectedRelationships)
        } catch {
            XCTAssert(false, "Storing relationships for Posts should not throw an error")
        }
    }
}
