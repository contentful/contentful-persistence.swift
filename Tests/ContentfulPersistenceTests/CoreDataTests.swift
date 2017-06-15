//
//  CoreDataTests.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 17/04/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

@testable import ContentfulPersistence
import Contentful
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

            do {
                let properties = try store.properties(for: Category.self)

                expect(Set(properties)).to(equal(Set(["title", "id", "createdAt", "updatedAt"])))
            } catch {
                XCTAssert(false, "Storing properties for Categories should not throw an error")
            }
        }

        it("can determine relationships of a type") {
            let store = CoreDataStore(context: self.managedObjectContext)

            do {
                let relationships = try store.relationships(for: Post.self)

                expect(relationships).to(equal(["author", "category", "featuredImage"]))
            } catch {
                XCTAssert(false, "Storing relationships for Posts should not throw an error")
            }
        }
    }
}
