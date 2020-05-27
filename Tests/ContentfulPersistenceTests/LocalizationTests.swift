//
//  LocalizationTests.swift
//  ContentfulPersistence
//
//  Created by JP Wright on 26.07.17.
//  Copyright © 2017 Contentful GmbH. All rights reserved.
//

@testable import ContentfulPersistence
import Contentful
import XCTest
import Foundation
import CoreData
import OHHTTPStubs
import CoreLocation

class LocalizationTests: XCTestCase {

    #if os(iOS) || os(macOS)
    let storeURL = FileManager.default.urls(for: .documentDirectory,
                                            in: .userDomainMask).last?.appendingPathComponent("LocalizationTest.sqlite")
    #elseif os(tvOS)
    let storeURL = FileManager.default.urls(for: .cachesDirectory,
                                            in: .userDomainMask).last?.appendingPathComponent("LocalizationTest.sqlite")
    #endif

    var syncManager: SynchronizationManager!

    var client: Client!

    lazy var store: CoreDataStore = {
        return CoreDataStore(context: TestHelpers.managedObjectContext(forMOMInTestBundleNamed: "LocalizationTest"))
    }()



    // Before each test.
    override func setUp() {
        HTTPStubs.removeAllStubs()

        let persistenceModel = PersistenceModel(spaceType: ComplexSyncInfo.self, assetType: ComplexAsset.self, entryTypes: [SingleRecord.self, Link.self])

        client = Client(spaceId: "smf0sqiu0c5s",
                        accessToken: "14d305ad526d4487e21a99b5b9313a8877ce6fbf540f02b12189eea61550ef34")
        syncManager = SynchronizationManager(client: client,
                                             localizationScheme: .all,
                                             persistenceStore: self.store,
                                             persistenceModel: persistenceModel)
    }

    // After each test.
    override func tearDown() {
        HTTPStubs.removeAllStubs()
    }

    func testLocalizedFieldValues() {

        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let stubPath = OHPathForFile("localization-sync.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
        }.name = "Initial sync stub"

        self.syncManager.sync { result in
            do {

                let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == 'aNt2d7YR4AIwEAMcG4OwI' AND localeCode == 'es-MX'"))
                XCTAssertEqual(records.count, 1)
                if let holaRecord = records.first {
                    XCTAssertEqual(holaRecord.textBody, "Hola")
                } else {
                    XCTFail("Expect record to exist")
                }

            } catch {
                XCTFail("Fetching SingleRecord should not throw an error")
            }

            expectation.fulfill()
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testLinkedEntriesAndAssets() {
        // This test pulls an entry that has a linking field ("linkField" in this case)
        // that links to different Entries for different locales.
        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let stubPath = OHPathForFile("localization-sync.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
        }.name = "Initial sync stub"

        self.syncManager.sync { result in
            do {

                let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '14XouHzspI44uKCcMicWUY' AND localeCode == 'es-MX'"))
                XCTAssertEqual(records.count, 1)
                if let recordWithLink = records.first {
                    XCTAssertNotNil(recordWithLink.linkField)
                    if let linkedField = recordWithLink.linkField {
                        XCTAssertEqual(linkedField.awesomeLinkTitle, "El segundo link")
                    } else {
                        XCTFail("Link should't be nil")
                    }
                } else {
                    XCTFail("Expect record to exist")
                }

            } catch {
                XCTFail("Fetching SingleRecord should not throw an error")
            }

            expectation.fulfill()
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testFallbackChainWorksForLinks() {
        // This test pulls an entry that has a linking field ("linkField" in this case)
        // that only has a linked entity for en-US English but not es-MX spanish.
        // We expect that the fallback chain is followed and the the linked entry for the english field is taken
        // and that additionally this linked entry (which happens to have a spanish "awsomeLinkTitle" field pulls the spanish
        // value.
        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let stubPath = OHPathForFile("localization-sync.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
        }.name = "Initial sync stub"

        self.syncManager.sync { result in
            do {

                let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '3Ck6MRrAJ2CaiasGKqeyao' AND localeCode == 'es-MX'"))
                XCTAssertEqual(records.count, 1)
                if let recordWithFallbackLink = records.first {
                    XCTAssertNotNil(recordWithFallbackLink.linkField)
                    if let linkedField = recordWithFallbackLink.linkField {
                        XCTAssertEqual(linkedField.awesomeLinkTitle, "Español")
                    } else {
                        XCTFail("Link should't be nil")
                    }
                } else {
                    XCTFail("Expect record to exist")
                }

            } catch {
                XCTFail("Fetching SingleRecord should not throw an error")
            }

            expectation.fulfill()
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testSyncingWithNonDefaultLocale() {
        let expectation = self.expectation(description: "Initial sync succeeded")

        stub(condition: isPath("/spaces/smf0sqiu0c5s/environments/master/sync")) { request -> HTTPStubsResponse in
            let stubPath = OHPathForFile("localization-sync.json", ComplexSyncTests.self)
            return fixture(filePath: stubPath!, headers: ["Content-Type": "application/json"])
            }.name = "Initial sync stub"


        self.syncManager.localizationScheme = .one("es-MX")

        self.syncManager.sync { result in
            do {

                let englishRecords: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '3Ck6MRrAJ2CaiasGKqeyao' AND localeCode == 'en-US'"))

                XCTAssertEqual(englishRecords.count, 0)

                let records: [SingleRecord] = try self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '3Ck6MRrAJ2CaiasGKqeyao' AND localeCode == 'es-MX'"))
                if let recordWithFallbackLink = records.first {
                    XCTAssertNotNil(recordWithFallbackLink.linkField)
                    if let linkedField = recordWithFallbackLink.linkField {
                        XCTAssertEqual(linkedField.awesomeLinkTitle, "Español")
                    } else {
                        XCTFail("Link should't be nil")
                    }
                } else {
                    XCTFail("Expect record to exist")
                }

            } catch {
                XCTFail("Fetching SingleRecord should not throw an error")
            }

            expectation.fulfill()
        }
        waitForExpectations(timeout: 10.0, handler: nil)

    }
}
