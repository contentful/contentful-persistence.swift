//
//  CoreDataTests.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 17/04/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

@testable import ContentfulPersistence
import Contentful
import CatchingFire
import Nimble
import Quick


class CoreDataTests: ContentfulPersistenceTestBase {
    lazy var store: CoreDataStore = {
        return CoreDataStore(context: self.managedObjectContext)
    }()

    override func spec() {
        it("can map Contentful results to managed objects") {
            // TODO: implement test
        }

        it("can determine properties of a type") {
            let store = CoreDataStore(context: self.managedObjectContext)

            AssertNoThrow {
                let relationships = try store.propertiesFor(type: Category.self)

                expect(relationships).to(equal(["title", "identifier"]))
            }
        }

        it("can determine relationships of a type") {
            let store = CoreDataStore(context: self.managedObjectContext)

            AssertNoThrow {
                let relationships = try store.relationshipsFor(type: Post.self)

                expect(relationships).to(equal(["author", "category", "featuredImage"]))
            }
        }
    }
}
