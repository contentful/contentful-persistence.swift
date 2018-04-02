//
//  NextSyncTests.swift
//  ContentfulPersistence
//
//  Created by JP Wright on 12.07.17.
//  Copyright © 2017 Contentful GmbH. All rights reserved.
//


@testable import ContentfulPersistence
import Contentful
import Interstellar
import XCTest
import Nimble
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

    func testUpdatingFieldValueBetweenSyncs() {

        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/sync")) { request -> OHHTTPStubsResponse in
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

        client.initialSync() { result in
            switch result {
            case .success(let space):
                syncSpace = space
                self.managedObjectContext.perform {
                    do {
                        let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == 'aNt2d7YR4AIwEAMcG4OwI'"))
                        expect(records.count).to(equal(1))
                        if let helloRecord = records.first {
                            expect(helloRecord.textBody).to(equal("Hello"))
                        }
                    } catch {
                        XCTAssert(false, "Fetching posts should not throw an error")
                    }
                    expectation.fulfill()
                }
            case .error(let error):
                fail("\(error)")
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0, handler: nil)
        OHHTTPStubs.removeAllStubs()

        // ============================NEXT SYNC==================================================
        let nextExpectation = self.expectation(description: "Next sync expectation")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/sync")) { request -> OHHTTPStubsResponse in
            return OHHTTPStubsResponse(
                fileAtPath: OHPathForFile("simple-update-next-sync.json", type(of: self))!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }.name = "Next sync: updated value."

        client.nextSync(for: syncSpace) { result in
            switch result {
            case .success:
                self.managedObjectContext.perform {
                    do {
                        let helloSingleRecord: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == 'aNt2d7YR4AIwEAMcG4OwI'"))
                        expect(helloSingleRecord.count).to(equal(1))
                        expect(helloSingleRecord.first!.textBody).to(equal("Hello FooBar"))
                    } catch {
                        XCTAssert(false, "Fetching posts should not throw an error")
                    }
                    nextExpectation.fulfill()
                }
            case .error(let error):
                fail("\(error)")
                nextExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testClearingFieldSetsItToNil() {
        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/sync")) { request -> OHHTTPStubsResponse in
            let stubPath = OHPathForFile("clear-field-initial-sync.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
            }.name = "Initial sync stub"

        var syncSpace: SyncSpace!

        client.initialSync() { result in
            switch result {
            case .success(let space):
                syncSpace = space
                self.managedObjectContext.perform {
                    do {
                        let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '5GiLOZvY7SiMeUIgIIAssS'"))
                        expect(records.count).to(equal(1))
                        if let record = records.first {
                            expect(record.textBody).to(equal("INITIAL TEXT BODY"))
                        }
                    } catch {
                        XCTAssert(false, "Fetching posts should not throw an error")
                    }
                    expectation.fulfill()
                }

            case .error(let error):
                fail("\(error)")
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0, handler: nil)
        OHHTTPStubs.removeAllStubs()

        // ============================NEXT SYNC==================================================
        let nextExpectation = self.expectation(description: "Next sync expectation")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/sync")) { request -> OHHTTPStubsResponse in
            let stubPath = OHPathForFile("clear-field-next-sync.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
        }.name = "Next sync: updated value."

        client.nextSync(for: syncSpace) { result in
            switch result {
            case .success:

                self.managedObjectContext.perform {
                    do {
                        let blankTextBodyRecord: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '5GiLOZvY7SiMeUIgIIAssS'"))
                        expect(blankTextBodyRecord.count).to(equal(1))
                        expect(blankTextBodyRecord.first!.textBody).to(beNil())
                    } catch {
                        XCTAssert(false, "Fetching posts should not throw an error")
                    }
                    nextExpectation.fulfill()
                }
            case .error(let error):
                fail("\(error)")
                nextExpectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testLinkResolutionForMultipageSync() {
        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/sync")) { request -> OHHTTPStubsResponse in
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

        client.initialSync() { result in
            switch result {
            case .success:

                self.managedObjectContext.perform {
                    do {
                        let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '14XouHzspI44uKCcMicWUY'"))
                        expect(records.count).to(equal(1))
                        if let record = records.first {
                            expect(record.linkField).toNot(beNil())
                            if let linkedField = record.linkField {
                                expect(linkedField.awesomeLinkTitle).to(equal("AWESOMELINK!!!"))
                            }
                        }
                    } catch {
                        fail("Fetching SingleRecord should not throw an error")
                    }
                    expectation.fulfill()
                }
            case .error(let error):
                fail("\(error)")
                expectation.fulfill()
            }

        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testNullifyingLinkBetweenSyncs() {
        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/sync")) { request -> OHHTTPStubsResponse in
            let stubPath = OHPathForFile("nullified-link-initial.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
        }.name = "Initial sync stub"

        var syncSpace: SyncSpace!

        client.initialSync() { result in
            switch result {
            case .success(let space):
                syncSpace = space

                self.managedObjectContext.perform {
                    do {
                        let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '5GiLOZvY7SiMeUIgIIAssS'"))
                        expect(records.count).to(equal(1))
                        if let record = records.first {
                            expect(record.linkField).toNot(beNil())
                            if let linkedField = record.linkField {
                                expect(linkedField.awesomeLinkTitle).to(equal("To be nullified"))
                            }
                        }
                    }
                    catch {
                        fail("Fetching SingleRecord should not throw an error")
                    }
                    expectation.fulfill()
                }

            case .error(let error):
                fail("\(error)")
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
        OHHTTPStubs.removeAllStubs()

        // ============================NEXT SYNC==================================================
        let nextExpectation = self.expectation(description: "Next sync expectation")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/sync")) { request -> OHHTTPStubsResponse in
            let stubPath = OHPathForFile("nullified-link-next.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
        }.name = "Next sync: updated value."

        client.nextSync(for: syncSpace) { result in
            switch result {
            case .success:

                self.managedObjectContext.perform {
                    do {
                        let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '5GiLOZvY7SiMeUIgIIAssS'"))
                        expect(records.first!.linkField).to(beNil())
                    } catch {
                        XCTAssert(false, "Fetching posts should not throw an error")
                    }
                    nextExpectation.fulfill()
                }
            case .error(let error):
                fail("\(error)")
                nextExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testDeserializingLocation() {
        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/sync")) { request -> OHHTTPStubsResponse in
            let stubPath = OHPathForFile("location.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
            }.name = "Initial sync stub"

        client.initialSync() { result in
            switch result {
            case .success:

                self.managedObjectContext.perform {
                    do {
                        let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '4VTL2TY7rikiS6c2MI2is4'"))
                        expect(records.count).to(equal(1))
                        if let record = records.first {
                            expect(record.locationField).toNot(beNil())
                            if let locationField = record.locationField {
                                expect(locationField.latitude).to(equal(34.4208305))
                            } else {
                                fail()
                            }
                        } else {
                            fail()
                        }
                    }
                    catch {
                        fail("Fetching SingleRecord should not throw an error")
                    }
                    expectation.fulfill()
                }

            case .error(let error):
                fail("\(error)")
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testDeserializingVideoAssetURL() {

        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/sync")) { request -> OHHTTPStubsResponse in
            let stubPath = OHPathForFile("video-asset.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
            }.name = "Initial sync stub"

        client.initialSync() { result in
            switch result {
            case .success:

                self.managedObjectContext.perform {
                    do {
                        let assets: [ComplexAsset] = try self.store.fetchAll(type: ComplexAsset.self,  predicate: NSPredicate(format: "id == 'YokO2rWbOoo68QmiEUkqe'"))
                        expect(assets.count).to(equal(1))
                        if let asset = assets.first {
                            expect(asset.urlString).toNot(beNil())
                            expect(asset.urlString).to(equal("https://videos.ctfassets.net/r3rkxrglg2d1/YokO2rWbOoo68QmiEUkqe/5cd5ab8fc90e7b9b4d99d56ea29de768/JP_Swift_Demo.mp4"))
                        } else {
                            fail()
                        }
                    }
                    catch {
                        fail("Fetching SingleRecord should not throw an error")
                    }
                    expectation.fulfill()
                }

            case .error(let error):
                fail("\(error)")
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 10.0, handler: nil)

    }

    func testEntriesLinkingToSameLinkCanResolveLinks() {
        let expectation = self.expectation(description: "Two entries can resolve links to the same asset")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/sync")) { request -> OHHTTPStubsResponse in
            let stubPath = OHPathForFile("shared-linked-asset.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
            }.name = "Initial sync stub"

        self.client.initialSync { result in
            switch result {
            case .success:
                // Test first entry can link to asset.
                let records: [SingleRecord] = try! self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '4DiVtM6u08uMA2QSgg0OoY'"))

                expect(records.count).to(equal(1))

                if let linkedAsset = records.first?.assetLinkField {
                    expect(linkedAsset.id).to(equal("6Wsz8owhtCGSICg44IUYAm"))
                    expect(linkedAsset.title).to(equal("First asset in array"))
                } else {
                    fail("There should be a linked asset")
                }

                // Test second entry can link to same asset
                let secondRecordsSet: [SingleRecord] = try! self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '12f37qR1CGOOcqoWOgqC2o'"))
                expect(secondRecordsSet.count).to(equal(1))

                if let linkedAsset = secondRecordsSet.first?.assetLinkField {
                    expect(linkedAsset.id).to(equal("6Wsz8owhtCGSICg44IUYAm"))
                    expect(linkedAsset.title).to(equal("First asset in array"))
                } else {
                    fail("There should be a linked asset")
                }
            case .error(let error):
                fail("Should not throw an error \(error)")
            }
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 10.0, handler: nil)
    }


    func testResolvingArrayOfLinkedAssets() {
        let expectation = self.expectation(description: "Can resolve relationship to linked assets array")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/sync")) { request -> OHHTTPStubsResponse in
            let stubPath = OHPathForFile("linked-assets-array.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
            }.name = "Initial sync stub"

        self.client.initialSync { result in
            switch result {
            case .success:
                let records: [SingleRecord] = try! self.store.fetchAll(type: SingleRecord.self, predicate: NSPredicate(format: "id == '2JFSeiPTZYm4goMSUeYSCU'"))

                expect(records.count).to(equal(1))

                if let linkedAssetsSet = records.first?.assetsArrayLinkField {
                    expect(linkedAssetsSet.count).to(equal(2))
                    expect((linkedAssetsSet.firstObject as? ComplexAsset)?.title).to(equal("First asset in array"))
                    expect((linkedAssetsSet[1] as? ComplexAsset)?.title).to(equal("Second asset in array"))
                } else {
                    fail("There should be a linked assets set")
                }
            case .error(let error):
                fail("Should not throw an error \(error)")
            }
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testDeserializingArrayOfStrings() {
        // TODO:
        let expectation = self.expectation(description: "Can deserialize linked strings array")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/sync")) { request -> OHHTTPStubsResponse in
            let stubPath = OHPathForFile("symbols-array.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
            }.name = "Initial sync stub"

        self.client.initialSync { result in
            switch result {
            case .success:
                let records: [SingleRecord] = try! self.store.fetchAll(type: SingleRecord.self, predicate: NSPredicate(format: "id == '2mhGzgf3oQOquo0SyGWCQE'"))

                expect(records.count).to(equal(1))

                if let linkedStringsData = records.first?.symbolsArray, let linkedStringsArray = NSKeyedUnarchiver.unarchiveObject(with: linkedStringsData) as? [String] {
                    expect(linkedStringsArray.count).to(equal(5))
                    expect(linkedStringsArray.first).to(equal("one"))
                    expect(linkedStringsArray.last).to(equal("five"))
                } else {
                    fail("There should be an array of linked strings")
                }
            case .error(let error):
                fail("Should not throw an error \(error)")
            }
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 10.0, handler: nil)    }

}
