//
//  ContentfulPersistenceTests.swift
//  ContentfulPersistenceTests
//
//  Created by Boris Bügling on 30/03/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

@testable import ContentfulPersistence
import ObjectMapper
import Contentful
import Nimble
import Quick
import CoreData

typealias TestFunc = (() -> ()) throws -> ()

class ContentfulPersistenceTests: QuickSpec {

    let assetPredicate = NSPredicate(format: "id == 'bXvdSYHB3Guy2uUmuEco8'")
    let postPredicate = NSPredicate(format: "id == '1asN98Ph3mUiCYIYiiqwko'")


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

    var client: Client!

    lazy var store: CoreDataStore = {
        return CoreDataStore(context: self.managedObjectContext)
    }()

    var sync: SynchronizationManager!

    func postTests(expectations: @escaping TestFunc) {
        waitUntil(timeout: 10) { done in
            self.client.initialSync() { result in
                expect(result.value).toNot(beNil())

                self.managedObjectContext.perform {
                    do {
                        let posts: [Post] = try self.store.fetchAll(type: Post.self, predicate: NSPredicate(value: true))
                        expect(posts.count).to(equal(2))
                        try expectations(done)
                    } catch {
                        XCTAssert(false, "Fetching posts should not throw an error")
                    }
                }
            }
        }
    }

    override func spec() {

        beforeEach {
            let entryTypes: [EntryPersistable.Type] = [Author.self, Category.self, Post.self]

            let persistenceModel = PersistenceModel(spaceType: SyncInfo.self, assetType: Asset.self, entryTypes: entryTypes)

            let synchronizationManager = SynchronizationManager(persistenceStore: self.store, persistenceModel: persistenceModel)

            self.client = Client(spaceId: "dqpnpm0n4e75", accessToken: "95c33f933385aa838825526c5753f3b5a7e59bb45cd6b5d78e15bfeafeef1b13", persistenceIntegration: synchronizationManager)
            self.sync = synchronizationManager

            self.deleteCoreDataStore()
        }

        it("can correctly infer property mapping") {
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
            let authorPropertyMapping = self.sync.propertyMapping(for: Author.self, and: author.fields)
            expect(authorPropertyMapping).to(equal(expectedPropertyMapping))
        }

        it("can correctly infer property mapping with explicitly defined mapping") {
            // We must have a space first to pass in locale information.
            let spaceMap = Map(mappingType: .fromJSON, JSON: TestHelpers.jsonData("space"))
            let space = try! Space(map: spaceMap)

            let localesContext = space.localizationContext

            let map = Map(mappingType: .fromJSON, JSON: TestHelpers.jsonData("single-post"), context: localesContext)
            let post = try! Entry(map: map)

            let expectedPropertyMapping: [FieldName: String] = [
                "title": "title"
            ]
            let postPropertyMapping = self.sync.propertyMapping(for: Post.self, and: post.fields)
            expect(postPropertyMapping).to(equal(expectedPropertyMapping))
        }

        it("can correctly infer relationship mapping") {
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
            let authorRelationshipMapping = self.sync.relationshipMapping(for: Author.self, and: author.fields)
            expect(authorRelationshipMapping).to(equal(expectedRelationshipMapping))
        }

        it("can correctly infer relationship mapping with explicitly defined mapping") {
            // We must have a space first to pass in locale information.
            let spaceMap = Map(mappingType: .fromJSON, JSON: TestHelpers.jsonData("space"))
            let space = try! Space(map: spaceMap)

            let localesContext = space.localizationContext

            let map = Map(mappingType: .fromJSON, JSON: TestHelpers.jsonData("single-post"), context: localesContext)
            let post = try! Entry(map: map)

            let expectedRelationshipMapping: [FieldName: String] = [
                "featuredImage": "theFeaturedImage",
                "author": "authors"
            ]
            let postRelationshiopMapping = self.sync.relationshipMapping(for: Post.self, and: post.fields)
            expect(postRelationshiopMapping).to(equal(expectedRelationshipMapping))
        }

        it("can store SyncTokens") { waitUntil(timeout: 10) { done in
            self.client.initialSync() { result in
                self.managedObjectContext.perform {
                    expect(result.value!.assets.count).to(beGreaterThan(0))
                    expect(self.sync.syncToken?.characters.count).to(beGreaterThan(0))

                    done()
                }
            }
        } }

        it("can continue syncing from an existing sync token") { waitUntil(timeout: 10) { done in
            let syncSpace = SyncSpace(syncToken: "w5ZGw6JFwqZmVcKsE8Kow4grw45QdybDqXt4XTFdw6tcwrMiwqpmwq7DlcOqZ8KnwpUiG1sZwr3Cq8OpFcKEUsOyPcOiQMOEITLDnyIkw4fDq8KAw6x_Mh3Dui_Cgw3CnsKswrwhw6hNwostejQDw4nDmUkp")
            self.client.nextSync(for: syncSpace) { result in
                expect(result.value!.entries.count).to(equal(0))
                done()
            }
        } }

        it("can store Assets") { waitUntil(timeout: 10) { done in
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
                    done()
                }
            }
        } }

        it("can store Entries") {
            self.postTests { done in
                let post: Post? = try! self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
                expect(post).toNot(beNil())
                expect(post?.title).to(equal("Down the Rabbit Hole"))
                done()
            }
        }

        it("can map Contentful Asset links to CoreData relationships") {
            self.postTests { done in
                let post: Post? = try self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
                expect(post).toNot(beNil())
                expect(post?.theFeaturedImage).toNot(beNil())
                expect(post?.theFeaturedImage?.urlString).toNot(beNil())
                expect(post?.theFeaturedImage?.urlString).to(equal("https://images.contentful.com/dqpnpm0n4e75/bXvdSYHB3Guy2uUmuEco8/608761ef6c0ef23815b410d5629208f9/alice-in-wonderland.gif"))

                done()
            }
        }

        it("can map Contentful Entry links to CoreData relationships") {
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

        it("respects user defined mappings when creating core data entities.") {
            self.postTests { done in
                let post: Post? = try self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
                expect(post).toNot(beNil())
                expect(post?.comments).to(beNil())
                expect(post?.title).toNot(beNil())
                expect(post?.theFeaturedImage).toNot(beNil())
                done()
            }
        }

        it("can determine properties of a type") {
            let store = CoreDataStore(context: self.managedObjectContext)

            do {
                let properties = try store.properties(for: Category.self)

                expect(Set(properties)).to(equal(Set(["title", "id", "createdAt", "updatedAt"])))
            } catch {
                XCTAssert(false, "Storing properties for Categories should not throw an error")
            }
        }

        it("can determine relationships of a CoreData type") {
            let store = CoreDataStore(context: self.managedObjectContext)

            do {
                let relationships = try store.relationships(for: Post.self)
                let expectedRelationships = ["authors", "theFeaturedImage", "category"]
                expect(relationships).to(equal(expectedRelationships))
            } catch {
                XCTAssert(false, "Storing relationships for Posts should not throw an error")
            }
        }
    }
}
