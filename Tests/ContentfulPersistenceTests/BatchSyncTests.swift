//
//  BatchSyncTests.swift
//  ContentfulPersistence
//
//  Created by Marius Kurgonas on 29/02/2024.
//  Copyright © 2024 Contentful GmbH. All rights reserved.
//

@testable import ContentfulPersistence
import Contentful
import XCTest
import Foundation
import CoreData
import OHHTTPStubs
import CoreLocation

class BatchSyncTests: XCTestCase {

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
        HTTPStubs.removeAllStubs()

        let persistenceModel = PersistenceModel(spaceType: ComplexSyncInfo.self, assetType: ComplexAsset.self, entryTypes: [SingleRecord.self, Link.self, RecordWithNonOptionalRelation.self])


        client = Client(spaceId: "smf0sqiu0c5s",
                        accessToken: "14d305ad526d4487e21a99b5b9313a8877ce6fbf540f02b12189eea61550ef34")
        self.syncManager = SynchronizationManager(client: client,
                                                  localizationScheme: .default,
                                                  persistenceStore: self.store,
                                                  persistenceModel: persistenceModel)
    }

    // After each test.
    override func tearDown() {
        HTTPStubs.removeAllStubs()
    }

    func testBatchUpdating() {

        let expectation = self.expectation(description: "testBatchUpdating")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let urlString = request.url!.absoluteString
            let queryItems = URLComponents(string: urlString)!.queryItems!
            for queryItem in queryItems {
                if queryItem.name == "initial" {
                    let stubPath = OHPathForFile("batch-page.json", ComplexSyncTests.self)
                    return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
                } else if queryItem.name == "sync_token" && queryItem.value == "wonDrcKnRgcSOF4-wrDCgcKefWzCgsOxwrfCq8KOfMOdXUPCvEnChwEEO8KFwqHDj8KIKHJYwr0Mw4wKw7UAVcOWYsOtw4nCvTUvDn0pw4gBRMKrGyVxIsOcQMKrwpfDhcOZwq3CkzDDvcKsJ8Oew58fJAQLwr3Cv2MGw4h6LcK_w4whQ8KMwr3ClMOhw5zDjMOswqAyw7XDpXDDsiXCvsKfw7JcwqjDucKmKMODwpDDlyvCrCnCjsOww43ClMKUwq8Xw75pXA" {
                    let stubPath = OHPathForFile("batch-page2.json", ComplexSyncTests.self)
                    return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
                }
            }
            let stubPath = OHPathForFile("simple-update-initial-sync.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
        }.name = "Initial sync stub"

        client.sync() { result in
            switch result {
            case .success(let space):
                // There are only SingleRecords, Links and ComplexAssets in stub files
                // All should be saved to CoreData
                self.managedObjectContext.perform {
                    do {
                        let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(value: true))
                        let links: [Link] = try self.store.fetchAll(type: Link.self,  predicate: NSPredicate(value: true))
                        XCTAssertEqual(records.count + links.count, space.entries.count)
                        let assets: [ComplexAsset] = try self.store.fetchAll(type: ComplexAsset.self, predicate: NSPredicate(value: true))
                        XCTAssertEqual(assets.count, space.assets.count)
                    } catch {
                        XCTAssert(false, "Fetching posts should not throw an error")
                    }
                    expectation.fulfill()
                }
            case .failure(let error):
                XCTFail("\(error)")
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0, handler: nil)
        HTTPStubs.removeAllStubs()
    }

}
