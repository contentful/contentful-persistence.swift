//
//  UnresolvedRelationshipCacheTests.swift
//  ContentfulPersistence
//
//  Created by JP Wright on 02.07.18.
//  Copyright © 2018 Contentful GmbH. All rights reserved.
//

@testable import ContentfulPersistence
import Contentful
import XCTest
import Foundation
import CoreData
import OHHTTPStubs
import CoreLocation

class UnresolvedRelationshipCacheTests: XCTestCase {

    var syncManager: SynchronizationManager!

    var client: Client!

    lazy var store: CoreDataStore = {
        return CoreDataStore(context: self.managedObjectContext)
    }()

    lazy var managedObjectContext: NSManagedObjectContext = {
        return TestHelpers.managedObjectContext(forMOMInTestBundleNamed: "ComplexTest")
    }()

    // Before each test.
    override func setUp() {
        OHHTTPStubs.removeAllStubs()

        let persistenceModel = PersistenceModel(spaceType: ComplexSyncInfo.self, assetType: ComplexAsset.self, entryTypes: [SingleRecord.self, Link.self])


        client = Client(spaceId: "smf0sqiu0c5s",
                        accessToken: "14d305ad526d4487e21a99b5b9313a8877ce6fbf540f02b12189eea61550ef34")
        self.syncManager = SynchronizationManager(client: client,
                                                  localizationScheme: .default,
                                                  persistenceStore: self.store,
                                                  persistenceModel: persistenceModel)
    }

    // After each test.
    override func tearDown() {
        OHHTTPStubs.removeAllStubs()
    }

    func testRelationshipsAreCachedMidSync() {
        var syncSpace: SyncSpace!

        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> OHHTTPStubsResponse in
            let stubPath = OHPathForFile("unresolvable-links.json", UnresolvedRelationshipCacheTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])

            }.name = "Initial sync stub"

        client.sync() { result in
            switch result {
            case .success(let space):
                XCTAssertFalse(self.syncManager.cachedUnresolvedRelationships!.isEmpty)
                XCTAssertEqual((self.syncManager.cachedUnresolvedRelationships?["14XouHzspI44uKCcMicWUY_en-US"])?["linkField"] as? String, "2XYdAPiR0I6SMAGiCOEukU_en-US")
                syncSpace = space
            case .error(let error):
                XCTFail("\(error)")

            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 10.0, handler: nil)
        OHHTTPStubs.removeAllStubs()

        // ============================NEXT SYNC==================================================
        let nextExpectation = self.expectation(description: "Next sync clears the cached JSON after relationships are resolved")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> OHHTTPStubsResponse in
            let stubPath = OHPathForFile("now-resolvable-relationships.json", UnresolvedRelationshipCacheTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
        }.name = "Next sync: relationships resolved."

        client.sync(for: syncSpace) { result in
            switch result {
            case .success:
                XCTAssertNil(self.syncManager.cachedUnresolvedRelationships)
            case .error(let error):
                XCTFail("\(error)")

            }
            nextExpectation.fulfill()
        }

        waitForExpectations(timeout: 10.0, handler: nil)
    }

}
