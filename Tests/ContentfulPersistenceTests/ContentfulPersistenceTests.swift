//
//  ContentfulPersistenceTests.swift
//  ContentfulPersistenceTests
//
//  Created by Boris Bügling on 30/03/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

@testable import ContentfulPersistence
import Contentful
import Nimble
import Quick

typealias TestFunc = (() -> ()) throws -> ()

class ContentfulPersistenceTests: ContentfulPersistenceTestBase {
    let assetPredicate = NSPredicate(format: "id == 'bXvdSYHB3Guy2uUmuEco8'")
    let postPredicate = NSPredicate(format: "id == '1asN98Ph3mUiCYIYiiqwko'")

    var client: Client!

    lazy var store: CoreDataStore = {
        return CoreDataStore(context: self.managedObjectContext)
    }()

    var sync: ContentfulSynchronizer!

    func postTests(expectations: @escaping TestFunc) {
        waitUntil(timeout: 10) { done in
            self.client.initialSync() { result in
                expect(result.value).toNot(beNil())

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

    override func spec() {

        beforeEach {
            let entryTypes: [EntryPersistable.Type] = [Author.self, Category.self, Post.self]

            let persistenceModel = PersistenceModel(spaceType: SyncInfo.self, assetType: Asset.self, entryTypes: entryTypes)

            let contentfulSynchronizer = ContentfulSynchronizer(persistenceStore: self.store, persistenceModel: persistenceModel)

            self.client = Client(spaceId: "dqpnpm0n4e75", accessToken: "95c33f933385aa838825526c5753f3b5a7e59bb45cd6b5d78e15bfeafeef1b13", persistenceDelegate: contentfulSynchronizer)
            self.sync = contentfulSynchronizer

            self.deleteCoreDataStore()
        }

        it("can store SyncTokens") { waitUntil(timeout: 10) { done in
            self.client.initialSync() { result in
                expect(result.value!.assets.count).to(beGreaterThan(0))
                expect(self.sync.syncToken?.characters.count).to(beGreaterThan(0))

                done()
            }
        } }

        it("can store Assets") { waitUntil(timeout: 10) { done in
            self.client.initialSync() { result in


                do {
                    let assets: [Asset] = try self.store.fetchAll(type: Asset.self, predicate: NSPredicate(value: true))
                    expect(assets.count).to(equal(6))

                    let alice: Asset? = try self.store.fetchAll(type: Asset.self, predicate: self.assetPredicate).first
                    expect(alice).toNot(beNil())
                    expect(alice?.title).to(equal("Alice in Wonderland"))
                    expect(alice?.urlString).to(equal("https://images.contentful.com/dqpnpm0n4e75/bXvdSYHB3Guy2uUmuEco8/608761ef6c0ef23815b410d5629208f9/alice-in-wonderland.gif"))
                } catch {
                    XCTAssert(false, "Fetching asset(s) should not throw an error")
                }

                done()
            }
        } }

        it("can store Entries") {
            self.postTests { done in
                let post: Post? = try self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
                expect(post).toNot(beNil())
                expect(post?.title).to(equal("Down the Rabbit Hole"))
                done()
            }
        }

        it("can map Contentful Asset links to CoreData relationships") {
            self.postTests { done in
                let post: Post? = try self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
                expect(post).toNot(beNil())

                expect(post?.featuredImage).toNot(beNil())
                expect(post?.featuredImage?.urlString).toNot(beNil())
                expect(post?.featuredImage?.urlString).to(equal("https://images.contentful.com/dqpnpm0n4e75/bXvdSYHB3Guy2uUmuEco8/608761ef6c0ef23815b410d5629208f9/alice-in-wonderland.gif"))

                done()
            }
        }

        it("can map Contentful Entry links to CoreData relationships") {
            self.postTests { done in
                let post: Post? = try self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
                expect(post).toNot(beNil())

                expect(post?.author).toNot(beNil())
                expect(post?.author?.count).to(equal(1))
                guard let author = post?.author?.firstObject as? Author else {
                    fail("was unable to make relationship")
                    done()
                    return
                }
                expect(author.name).toNot(beNil())
                expect(author.name).to(equal("Lewis Carroll"))
                done()
            }
        }

        it("can continue syncing from an existing data store") {
            // TODO: implement test
        }
    }
}
