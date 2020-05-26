//
//  NextSyncTests.swift
//  ContentfulPersistence
//
//  Created by JP Wright on 12.07.17.
//  Copyright © 2017 Contentful GmbH. All rights reserved.
//


@testable import ContentfulPersistence
import Contentful
import XCTest
import Foundation
import CoreData
import OHHTTPStubs
import CoreLocation

class ComplexSyncTests: XCTestCase {

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

    func testUpdatingFieldValueBetweenSyncs() {

        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let urlString = request.url!.absoluteString
            let queryItems = URLComponents(string: urlString)!.queryItems!
            for queryItem in queryItems {
                if queryItem.name == "initial" {
                    let stubPath = OHPathForFile("simple-update-initial-sync.json", ComplexSyncTests.self)
                    return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
                } else if queryItem.name == "sync_token" && queryItem.value == "wonDrcKnRgcSOF4-wrDCgcKefWzCgsOxwrfCq8KOfMOdXUPCvEnChwEEO8KFwqHDj8KIKHJYwr0Mw4wKw7UAVcOWYsOtw4nCvTUvDn0pw4gBRMKrGyVxIsOcQMKrwpfDhcOZwq3CkzDDvcKsJ8Oew58fJAQLwr3Cv2MGw4h6LcK_w4whQ8KMwr3ClMOhw5zDjMOswqAyw7XDpXDDsiXCvsKfw7JcwqjDucKmKMODwpDDlyvCrCnCjsOww43ClMKUwq8Xw75pXA" {
                    let stubPath = OHPathForFile("simple-update-initial-sync-page2.json", ComplexSyncTests.self)
                    return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
                }
            }
            let stubPath = OHPathForFile("simple-update-initial-sync.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
        }.name = "Initial sync stub"

        var syncSpace: SyncSpace!

        client.sync() { result in
            switch result {
            case .success(let space):
                syncSpace = space
                self.managedObjectContext.perform {
                    do {
                        let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == 'aNt2d7YR4AIwEAMcG4OwI'"))
                        XCTAssertEqual(records.count, 1)
                        if let helloRecord = records.first {
                            XCTAssertFalse(helloRecord.hasChanges, "Record has not yet been saved")
                            XCTAssertEqual(helloRecord.textBody, "Hello")
                        }
                    } catch {
                        XCTAssert(false, "Fetching posts should not throw an error")
                    }
                    expectation.fulfill()
                }
            case .error(let error):
                XCTFail("\(error)")
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0, handler: nil)
        HTTPStubs.removeAllStubs()

        // ============================NEXT SYNC==================================================
        let nextExpectation = self.expectation(description: "Next sync expectation")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            return HTTPStubsResponse(
                fileAtPath: OHPathForFile("simple-update-next-sync.json", type(of: self))!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }.name = "Next sync: updated value."

        client.sync(for: syncSpace) { result in
            switch result {
            case .success:
                self.managedObjectContext.perform {
                    do {
                        let helloSingleRecord: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == 'aNt2d7YR4AIwEAMcG4OwI'"))
                        XCTAssertEqual(helloSingleRecord.count, 1)
                        XCTAssertFalse(helloSingleRecord.first!.hasChanges, "Record has not yet been saved")
                        XCTAssertEqual(helloSingleRecord.first!.textBody, "Hello FooBar")
                    } catch {
                        XCTAssert(false, "Fetching posts should not throw an error")
                    }
                    nextExpectation.fulfill()
                }
            case .error(let error):
                XCTFail("\(error)")
                nextExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testClearingFieldSetsItToNil() {
        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let stubPath = OHPathForFile("clear-field-initial-sync.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
            }.name = "Initial sync stub"

        var syncSpace: SyncSpace!

        client.sync() { result in
            switch result {
            case .success(let space):
                syncSpace = space
                self.managedObjectContext.perform {
                    do {
                        let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '5GiLOZvY7SiMeUIgIIAssS'"))
                        XCTAssertEqual(records.count, 1)
                        if let record = records.first {
                            XCTAssertFalse(record.hasChanges, "Record has not yet been saved")
                            XCTAssertEqual(record.textBody, "INITIAL TEXT BODY")
                        }
                    } catch {
                        XCTAssert(false, "Fetching posts should not throw an error")
                    }
                    expectation.fulfill()
                }

            case .error(let error):
                XCTFail("\(error)")
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0, handler: nil)
        HTTPStubs.removeAllStubs()

        // ============================NEXT SYNC==================================================
        let nextExpectation = self.expectation(description: "Next sync expectation")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let stubPath = OHPathForFile("clear-field-next-sync.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
        }.name = "Next sync: updated value."

        client.sync(for: syncSpace) { result in
            switch result {
            case .success:

                self.managedObjectContext.perform {
                    do {
                        let blankTextBodyRecord: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '5GiLOZvY7SiMeUIgIIAssS'"))
                        XCTAssertEqual(blankTextBodyRecord.count, 1)
                        XCTAssertFalse(blankTextBodyRecord.first?.hasChanges ?? false, "Record has not yet been saved")
                        XCTAssertNil(blankTextBodyRecord.first!.textBody)
                    } catch {
                        XCTAssert(false, "Fetching posts should not throw an error")
                    }
                    nextExpectation.fulfill()
                }
            case .error(let error):
                XCTFail("\(error)")
                nextExpectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testLinkResolutionForMultipageSync() {
        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let urlString = request.url!.absoluteString
            let queryItems = URLComponents(string: urlString)!.queryItems!
            for queryItem in queryItems {
                if queryItem.name == "initial" {
                    let stubPath = OHPathForFile("multi-page-link-resolution1.json", ComplexSyncTests.self)
                    return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
                } else if queryItem.name == "sync_token" && queryItem.value == "multi-page-link-resolution-token" {
                    let stubPath = OHPathForFile("multi-page-link-resolution2.json", ComplexSyncTests.self)
                    return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
                }
            }
            let stubPath = OHPathForFile("simple-update-initial-sync.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
        }.name = "Initial sync stub"

        client.sync() { result in
            switch result {
            case .success:

                self.managedObjectContext.perform {
                    do {
                        let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '14XouHzspI44uKCcMicWUY'"))
                        XCTAssertEqual(records.count, 1)
                        if let record = records.first {
                            XCTAssertFalse(record.hasChanges, "Record has not yet been saved")
                            XCTAssertNotNil(record.linkField)
                            if let linkedField = record.linkField {
                                XCTAssertEqual(linkedField.awesomeLinkTitle, "AWESOMELINK!!!")
                            }
                        }
                    } catch {
                        XCTFail("Fetching SingleRecord should not throw an error")
                    }
                    expectation.fulfill()
                }
            case .error(let error):
                XCTFail("\(error)")
                expectation.fulfill()
            }

        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testNullifyingLinkBetweenSyncs() {
        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let stubPath = OHPathForFile("nullified-link-initial.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
        }.name = "Initial sync stub"

        var syncSpace: SyncSpace!

        client.sync { result in
            switch result {
            case .success(let space):
                syncSpace = space

                self.managedObjectContext.perform {
                    do {
                        let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '5GiLOZvY7SiMeUIgIIAssS'"))
                        XCTAssertEqual(records.count, 1)
                        if let record = records.first {
                            XCTAssertFalse(record.hasChanges, "Record has not yet been saved")
                            XCTAssertNotNil(record.linkField)
                            if let linkedField = record.linkField {
                                XCTAssertEqual(linkedField.awesomeLinkTitle, "To be nullified")
                            }
                        }
                    }
                    catch {
                        XCTFail("Fetching SingleRecord should not throw an error")
                    }
                    expectation.fulfill()
                }

            case .error(let error):
                XCTFail("\(error)")
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
        HTTPStubs.removeAllStubs()

        // ============================NEXT SYNC==================================================
        let nextExpectation = self.expectation(description: "Next sync expectation")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let stubPath = OHPathForFile("nullified-link-next.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
        }.name = "Next sync: updated value."

        client.sync(for: syncSpace) { result in
            switch result {
            case .success:

                self.managedObjectContext.perform {
                    do {
                        let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '5GiLOZvY7SiMeUIgIIAssS'"))
                        XCTAssertNil(records.first!.linkField)
                    } catch {
                        XCTAssert(false, "Fetching posts should not throw an error")
                    }
                    nextExpectation.fulfill()
                }
            case .error(let error):
                XCTFail("\(error)")
                nextExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0, handler: nil)
    }


    func testDeletingEntryForOneLocaleDeletesCoreDataEntityBetweenSyncs() {
        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let stubPath = OHPathForFile("deleted-entry-initial.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
            }.name = "Initial sync stub"

        var syncSpace: SyncSpace!

        client.sync { result in
            switch result {
            case .success(let space):
                syncSpace = space

                self.managedObjectContext.perform {
                    do {
                        let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == 'aNt2d7YR4AIwEAMcG4OwI'"))
                        XCTAssertEqual(records.count, 1)
                        if let record = records.first {
                            XCTAssertFalse(record.hasChanges, "Record has not yet been saved")
                            XCTAssertEqual(record.textBody, "Hello")
                        }
                    }
                    catch {
                        XCTFail("Fetching SingleRecord should not throw an error")
                    }
                    expectation.fulfill()
                }

            case .error(let error):
                XCTFail("\(error)")
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
        HTTPStubs.removeAllStubs()

        // ============================NEXT SYNC==================================================
        let nextExpectation = self.expectation(description: "Next sync expectation")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let stubPath = OHPathForFile("deleted-entry-next.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
            }.name = "Next sync: updated value."

        client.sync(for: syncSpace) { result in
            switch result {
            case .success:

                self.managedObjectContext.perform {
                    do {
                        let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == 'aNt2d7YR4AIwEAMcG4OwI'"))
                        XCTAssertNil(records.first)
                        XCTAssertEqual(records.count, 0)
                    } catch {
                        XCTAssert(false, "Fetching SingleRecord should not throw an error")
                    }
                    nextExpectation.fulfill()
                }
            case .error(let error):
                XCTFail("\(error)")
                nextExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testDeletingEntryForMultiLocaleDeletesCoreDataEntitiesBetweenSyncs() {
        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let stubPath = OHPathForFile("deleted-entry-initial.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
            }.name = "Initial sync stub"

        var syncSpace: SyncSpace!
        syncManager.localizationScheme = .all

        client.sync { result in
            switch result {
            case .success(let space):
                syncSpace = space

                self.managedObjectContext.perform {
                    do {
                        let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(value: true))
                        XCTAssertEqual(records.count, 2)
                        if let record = records.filter({ $0.localeCode == "en-US" }).first {
                            XCTAssertFalse(record.hasChanges, "Record has not yet been saved")
                            XCTAssertEqual(record.textBody, "Hello")
                        }
                        if let record = records.filter({ $0.localeCode == "es-MX" }).first {
                            XCTAssertFalse(record.hasChanges, "Record has not yet been saved")
                            XCTAssertEqual(record.textBody, "Hola")
                        }
                    }
                    catch {
                        XCTFail("Fetching SingleRecord should not throw an error")
                    }
                    expectation.fulfill()
                }

            case .error(let error):
                XCTFail("\(error)")
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
        HTTPStubs.removeAllStubs()

        // ============================NEXT SYNC==================================================
        let nextExpectation = self.expectation(description: "Next sync expectation")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let stubPath = OHPathForFile("deleted-entry-next.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
            }.name = "Next sync: updated value."

        client.sync(for: syncSpace) { result in
            switch result {
            case .success:

                self.managedObjectContext.perform {
                    do {
                        let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(value: true))
                        XCTAssertNil(records.first)
                        XCTAssertEqual(records.count, 0)
                    } catch {
                        XCTAssert(false, "Fetching SingleRecord should not throw an error")
                    }
                    nextExpectation.fulfill()
                }
            case .error(let error):
                XCTFail("\(error)")
                nextExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0, handler: nil)
    }


    func testDeletingAssetForOneLocaleDeletesCoreDataEntityBetweenSyncs() {
        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let stubPath = OHPathForFile("deleted-asset-initial.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
            }.name = "Initial sync stub"

        var syncSpace: SyncSpace!

        client.sync { result in
            switch result {
            case .success(let space):
                syncSpace = space

                self.managedObjectContext.perform {
                    do {
                        let assets: [ComplexAsset] = try self.store.fetchAll(type: ComplexAsset.self,  predicate: NSPredicate(format: "id == 'YokO2rWbOoo68QmiEUkqe'"))
                        XCTAssertEqual(assets.count, 1)
                        if let asset = assets.first {
                            XCTAssertFalse(asset.hasChanges, "Asset has not yet been saved")
                            XCTAssertEqual(asset.title, "Video asset")
                        }
                    }
                    catch {
                        XCTFail("Fetching Asset should not throw an error")
                    }
                    expectation.fulfill()
                }

            case .error(let error):
                XCTFail("\(error)")
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
        HTTPStubs.removeAllStubs()

        // ============================NEXT SYNC==================================================
        let nextExpectation = self.expectation(description: "Next sync expectation")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let stubPath = OHPathForFile("deleted-asset-next.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
            }.name = "Next sync: updated value."

        client.sync(for: syncSpace) { result in
            switch result {
            case .success:

                self.managedObjectContext.perform {
                    do {
                        let assets: [ComplexAsset] = try self.store.fetchAll(type: ComplexAsset.self, predicate: NSPredicate(format: "id == 'YokO2rWbOoo68QmiEUkqe'"))
                        XCTAssertNil(assets.first)
                        XCTAssertEqual(assets.count, 0)
                    } catch {
                        XCTAssert(false, "Fetching asset should not throw an error")
                    }
                    nextExpectation.fulfill()
                }
            case .error(let error):
                XCTFail("\(error)")
                nextExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testDeserializingLocation() {
        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let stubPath = OHPathForFile("location.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
            }.name = "Initial sync stub"

        client.sync { result in
            switch result {
            case .success:

                self.managedObjectContext.perform {
                    do {
                        let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '4VTL2TY7rikiS6c2MI2is4'"))
                        XCTAssertEqual(records.count, 1)
                        if let record = records.first {
                            XCTAssertFalse(record.hasChanges, "Record has not yet been saved")
                            XCTAssertNotNil(record.locationField)
                            if let locationField = record.locationField {
                                XCTAssertEqual(locationField.latitude, 34.4208305)
                            } else {
                                XCTFail()
                            }
                        } else {
                            XCTFail()
                        }
                    }
                    catch {
                        XCTFail("Fetching SingleRecord should not throw an error")
                    }
                    expectation.fulfill()
                }

            case .error(let error):
                XCTFail("\(error)")
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testDeserializingVideoAssetURL() {

        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let stubPath = OHPathForFile("video-asset.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
            }.name = "Initial sync stub"

        client.sync { result in
            switch result {
            case .success:

                self.managedObjectContext.perform {
                    do {
                        let assets: [ComplexAsset] = try self.store.fetchAll(type: ComplexAsset.self,  predicate: NSPredicate(format: "id == 'YokO2rWbOoo68QmiEUkqe'"))
                        XCTAssertEqual(assets.count, 1)
                        if let asset = assets.first {
                            XCTAssertFalse(asset.hasChanges, "Asset has not yet been saved")
                            XCTAssertNotNil(asset.urlString)
                            XCTAssertEqual(asset.urlString ,"https://videos.ctfassets.net/r3rkxrglg2d1/YokO2rWbOoo68QmiEUkqe/5cd5ab8fc90e7b9b4d99d56ea29de768/JP_Swift_Demo.mp4")
                        } else {
                            XCTFail()
                        }
                    }
                    catch {
                        XCTFail("Fetching SingleRecord should not throw an error")
                    }
                    expectation.fulfill()
                }

            case .error(let error):
                XCTFail("\(error)")
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)

    }

    func testEntriesLinkingToSameLinkCanResolveLinks() {
        let expectation = self.expectation(description: "Two entries can resolve links to the same asset")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let stubPath = OHPathForFile("shared-linked-asset.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
            }.name = "Initial sync stub"

        self.client.sync { result in
            switch result {
            case .success:
                // Test first entry can link to asset.
                let records: [SingleRecord] = try! self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '4DiVtM6u08uMA2QSgg0OoY'"))

                XCTAssertEqual(records.count, 1)

                if let linkedAsset = records.first?.assetLinkField {
                    XCTAssertFalse(linkedAsset.hasChanges, "Asset has not yet been saved")
                    XCTAssertEqual(linkedAsset.id, "6Wsz8owhtCGSICg44IUYAm")
                    XCTAssertEqual(linkedAsset.title, "First asset in array")
                } else {
                    XCTFail("There should be a linked asset")
                }

                // Test second entry can link to same asset
                let secondRecordsSet: [SingleRecord] = try! self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '12f37qR1CGOOcqoWOgqC2o'"))
                XCTAssertEqual(secondRecordsSet.count, 1)

                if let linkedAsset = secondRecordsSet.first?.assetLinkField {
                    XCTAssertFalse(linkedAsset.hasChanges, "Asset has not yet been saved")
                    XCTAssertEqual(linkedAsset.id, "6Wsz8owhtCGSICg44IUYAm")
                    XCTAssertEqual(linkedAsset.title, "First asset in array")
                } else {
                    XCTFail("There should be a linked asset")
                }
            case .error(let error):
                XCTFail("Should not throw an error \(error)")
            }
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 10.0, handler: nil)
    }


    func testResolvingArrayOfLinkedAssets() {
        let expectation = self.expectation(description: "Can resolve relationship to linked assets array")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let stubPath = OHPathForFile("linked-assets-array.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
            }.name = "Initial sync stub"

        self.client.sync { result in
            switch result {
            case .success:
                let records: [SingleRecord] = try! self.store.fetchAll(type: SingleRecord.self, predicate: NSPredicate(format: "id == '2JFSeiPTZYm4goMSUeYSCU'"))

                XCTAssertEqual(records.count, 1)

                if let linkedAssetsSet = records.first?.assetsArrayLinkField {
                    XCTAssertFalse(records.first!.hasChanges, "Record has not yet been saved")
                    XCTAssertEqual(linkedAssetsSet.count, 2)
                    XCTAssertEqual((linkedAssetsSet.firstObject as? ComplexAsset)?.title, "First asset in array")
                    XCTAssertEqual((linkedAssetsSet[1] as? ComplexAsset)?.title, "Second asset in array")
                } else {
                    XCTFail("There should be a linked assets set")
                }
            case .error(let error):
                XCTFail("Should not throw an error \(error)")
            }
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testDeserializingArrayOfStrings() {
        // TODO:
        let expectation = self.expectation(description: "Can deserialize linked strings array")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let stubPath = OHPathForFile("symbols-array.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
            }.name = "Initial sync stub"

        self.client.sync { result in
            switch result {
            case .success:
                let records: [SingleRecord] = try! self.store.fetchAll(type: SingleRecord.self, predicate: NSPredicate(format: "id == '2mhGzgf3oQOquo0SyGWCQE'"))

                XCTAssertEqual(records.count, 1)

                if let linkedStringsData = records.first?.symbolsArray, let linkedStringsArray = NSKeyedUnarchiver.unarchiveObject(with: linkedStringsData) as? [String] {
                    XCTAssertFalse(records.first!.hasChanges, "Record has not yet been saved")
                    XCTAssertEqual(linkedStringsArray.count, 5)
                    XCTAssertEqual(linkedStringsArray.first, "one")
                    XCTAssertEqual(linkedStringsArray.last, "five")
                } else {
                    XCTFail("There should be an array of linked strings")
                }
            case .error(let error):
                XCTFail("Should not throw an error \(error)")
            }
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 10.0, handler: nil)

    }

    func testNonOptionalLinkResolutionForMultipageSync() {
        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(
            condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync"),
            response: { request -> HTTPStubsResponse in
                let urlString = request.url!.absoluteString
                let queryItems = URLComponents(string: urlString)!.queryItems!
                for queryItem in queryItems {
                    switch queryItem.name {
                    case "initial":
                        let stubPath = OHPathForFile(
                            "multi-page-non-optional-link-resolution1.json",
                            ComplexSyncTests.self
                        )
                        return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
                    case "sync_token" where queryItem.value == "multi-page-non-optional-link-resolution-token":
                        let stubPath = OHPathForFile(
                            "multi-page-non-optional-link-resolution2.json",
                            ComplexSyncTests.self
                        )
                        return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
                    default:
                        continue
                    }
                }
                XCTFail("Unexpected request cannot be stubbed!")
                return HTTPStubsResponse(
                    error: NSError(domain: "ComplexSyncTests", code: 10, userInfo: nil)
                )
            }
        ).name = "Initial sync stub"

        client.sync() { result in
            switch result {
            case .success:

                self.managedObjectContext.perform {
                    do {
                        let records: [RecordWithNonOptionalRelation] = try self.store.fetchAll(
                            type: RecordWithNonOptionalRelation.self,
                            predicate: NSPredicate(format: "id == '15OmnIzspI44uKCcNzcPUS'")
                        )
                        XCTAssertEqual(records.count, 1)
                        if let record = records.first {
                            XCTAssertEqual(record.nonOptionalLink.awesomeLinkTitle, "Non-optional Link")
                            XCTAssertFalse(record.hasChanges, "Link has not yet been saved")
                            XCTAssertFalse(record.nonOptionalLink.hasChanges, "Link has not yet been saved")
                        }
                    } catch {
                        XCTFail("Fetching RecordWithNonOptionalRelation should not throw an error")
                    }
                    expectation.fulfill()
                }
            case .error(let error):
                XCTFail("\(error)")
                expectation.fulfill()
            }

        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

}
