//
//  ContentfulPersistenceTests.swift
//  ContentfulPersistenceTests
//
//  Created by Boris Bügling on 30/03/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

import CatchingFire
import Interstellar
import Nimble
import Quick

import Contentful
@testable import ContentfulPersistence

typealias TestFunc = (() -> ()) throws -> ()

class ContentfulPersistenceTests: ContentfulPersistenceTestBase {
    lazy var client: Client = {
        let spaceId = "dqpnpm0n4e75" // => https://app.contentful.com/spaces/dqpnpm0n4e75
        let accessToken = "95c33f933385aa838825526c5753f3b5a7e59bb45cd6b5d78e15bfeafeef1b13"

        return Client(spaceIdentifier: spaceId, accessToken: accessToken)
    }()

    lazy var store: CoreDataStore = {
        return CoreDataStore(context: self.managedObjectContext)
    }()

    lazy var sync: ContentfulSynchronizer = {
        let sync = ContentfulSynchronizer(client: self.client, persistenceStore: self.store)

        sync.mapAssets(to: Asset.self)
        sync.mapSpaces(to: SyncInfo.self)

        sync.map(contentTypeId: "1kUEViTN4EmGiEaaeC6ouY", to: Author.self)
        sync.map(contentTypeId: "5KMiN6YPvi42icqAUQMCQe", to: Category.self)
        sync.map(contentTypeId: "2wKn6yEnZewu2SCCkus4as", to: Post.self)

        return sync
    }()

    func postTests(expectations: TestFunc) {
        waitUntil { done in
            self.sync.sync() {
                expect($0).to(beTrue())

                AssertNoThrow {
                    let posts: [Post] = try self.store.fetchAll(Post.self, predicate: NSPredicate(value: true))
                    expect(posts.count).to(equal(3))

                    try expectations(done)
                }
            }
        }
    }

    override func spec() {
        it("can store SyncTokens") { waitUntil { done in
            self.sync.sync() {
                expect($0).to(beTrue())
                expect(self.sync.syncToken?.characters.count).to(beGreaterThan(0))

                done()
            }
        } }

        it("can store Assets") { waitUntil { done in
            self.sync.sync() {
                expect($0).to(beTrue())

                AssertNoThrow {
                    let assets: [Asset] = try self.store.fetchAll(Asset.self, predicate: NSPredicate(value: true))
                    expect(assets.count).to(equal(6))

                    let alice: Asset? = try self.store.fetchAll(Asset.self, predicate: NSPredicate(format: "identifier == 'bXvdSYHB3Guy2uUmuEco8'")).first
                    expect(alice).toNot(beNil())
                    expect(alice?.title).to(equal("Alice in Wonderland"))
                    expect(alice?.url).to(equal("https://images.contentful.com/dqpnpm0n4e75/bXvdSYHB3Guy2uUmuEco8/608761ef6c0ef23815b410d5629208f9/alice-in-wonderland.gif"))
                }

                done()
            }
        } }

        it("can store Entries") {
            self.postTests { done in
                let post: Post? = try self.store.fetchAll(Post.self, predicate: NSPredicate(format: "identifier == '1asN98Ph3mUiCYIYiiqwko'")).first
                expect(post).toNot(beNil())
                done()
            }
        }

        it("can map Contentful links to CoreData relationships") {
            // TODO: implement test
        }

        it("can continue syncing from an existing data store") {
            // TODO: implement test
        }
    }
}
