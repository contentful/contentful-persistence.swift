import Contentful
@testable import ContentfulPersistence
import XCTest

class SynchronizationManagerSyncTests: XCTestCase {
    var sut: SynchronizationManager!
    var client: Client!
    var persistenceStore: MockPersistenceStore!

    override func setUp() {
        super.setUp()
        
        persistenceStore = MockPersistenceStore()
        persistenceStore.returnValue = MockSyncSpacePersistable()

        client = Client(
            spaceId: "spaceId",
            accessToken: "accessToken",
            sessionConfiguration: {
                let config = URLSessionConfiguration.ephemeral
                config.protocolClasses = [MockURLProtocol.self]
                return config
            }()
        )
        
        MockURLProtocol.mockURLs =
            [
                .sync: (
                    nil,
                    Data.sync,
                    HTTPURLResponse(
                        url: .sync,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )
                ),
                .locales: (
                    nil,
                    Data.locales,
                    HTTPURLResponse(
                        url: .locales,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )
                ),
                .contentTypes: (
                    nil,
                    Data.contentTypes,
                    HTTPURLResponse(
                        url: .contentTypes,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                        )
                    )
            ]

        sut = SynchronizationManager(
            client: client,
            localizationScheme: .all,
            persistenceStore: persistenceStore,
            persistenceModel: .init(spaceType: MockSyncSpacePersistable.self, assetType: Asset.self, entryTypes: [])
        )
    }

    func testInvalidLocalizationScheme() throws {
        XCTAssertThrowsError(
            try sut
                .sync(
                    syncSpacePersistable: MockSyncSpacePersistable.self,
                    initialLocalizationScheme: .all,
                    onInitialCompletion: { _ in },
                    onFinalCompletion: { _ in }
                )
        )
    }

    func testPartialResultIsCalled() throws {
        let expectation = self.expectation(description: "Partial result is called")

        try sut
            .sync(
                syncSpacePersistable: MockSyncSpacePersistable.self,
                initialLocalizationScheme: .default,
                onInitialCompletion: { _ in
                    expectation.fulfill()
                },
                onFinalCompletion: { _ in }
            )

        wait(for: [expectation], timeout: 1)
    }
    
    func testSecondSyncIsCalledWithLocalizationSchemeAll() throws {
        let expectation = self.expectation(description: "Second sync is called with all")
        
        try sut
            .sync(
                syncSpacePersistable: MockSyncSpacePersistable.self,
                initialLocalizationScheme: .default,
                onInitialCompletion: { _ in },
                onFinalCompletion: { _ in
                    expectation.fulfill()
                }
                )
        
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(sut.localizationScheme, .all)
    }
}

extension LocalizationScheme: @retroactive Equatable {
    public static func == (lhs: LocalizationScheme, rhs: LocalizationScheme) -> Bool {
        switch (lhs, rhs) {
        case (.default, .default), (.all, .all):
            return true
        default:
            fatalError("Not implemented")
        }
    }
}

extension URL {
    static var locales: URL =
        .init(string: "https://cdn.contentful.com/spaces/spaceId/environments/master/locales?limit=1000")!

    static var sync: URL =
        .init(string: "https://cdn.contentful.com/spaces/spaceId/environments/master/sync?initial=true")!

    static var contentTypes: URL =
        .init(string: "https://cdn.contentful.com/spaces/spaceId/environments/master/content_types")!
}

extension Data {
    static var locales: Data {
        """
        {
          "sys": {
            "type": "Array"
          },
          "total": 1,
          "skip": 0,
          "limit": 1000,
          "items": [
            {
              "code": "en-US",
              "name": "English (United States)",
              "default": true,
              "fallbackCode": null,
              "sys": {
                "id": "0ggPubR5brt54LzgvLHKgp",
                "type": "Locale",
                "version": 1
              }
            }
          ]
        }
        """.data(using: .utf8)!
    }

    static var sync: Data {
        """
        {
          "sys": {
            "type": "Array"
          },
          "items": [
            {
              "metadata": {
                "tags": [],
                "concepts": []
              },
              "sys": {
                "space": {
                  "sys": {
                    "type": "Link",
                    "linkType": "Space",
                    "id": "tqsqhc19q5j2"
                  }
                },
                "id": "17sOppAtMCfWqkvYZIySeW",
                "type": "Entry",
                "createdAt": "2024-11-12T09:29:12.813Z",
                "updatedAt": "2024-11-13T12:40:18.793Z",
                "environment": {
                  "sys": {
                    "id": "master",
                    "type": "Link",
                    "linkType": "Environment"
                  }
                },
                "publishedVersion": 11,
                "revision": 4,
                "contentType": {
                  "sys": {
                    "type": "Link",
                    "linkType": "ContentType",
                    "id": "product"
                  }
                }
              },
              "fields": {
                "name": {
                  "en-US": "Foo"
                },
                "relatedProducts": {
                  "en-US": [
                    {
                      "sys": {
                        "type": "Link",
                        "linkType": "Entry",
                        "id": "1dDexhBlfHfKrJnAgDOZPV"
                      }
                    },
                    {
                      "sys": {
                        "type": "Link",
                        "linkType": "Entry",
                        "id": "47zFJurPeDiFwg4ikOZULs"
                      }
                    }
                  ]
                }
              }
            },
            {
              "metadata": {
                "tags": [],
                "concepts": []
              },
              "sys": {
                "space": {
                  "sys": {
                    "type": "Link",
                    "linkType": "Space",
                    "id": "tqsqhc19q5j2"
                  }
                },
                "id": "47zFJurPeDiFwg4ikOZULs",
                "type": "Entry",
                "createdAt": "2024-11-12T15:28:28.390Z",
                "updatedAt": "2024-11-12T15:28:28.390Z",
                "environment": {
                  "sys": {
                    "id": "master",
                    "type": "Link",
                    "linkType": "Environment"
                  }
                },
                "publishedVersion": 2,
                "revision": 1,
                "contentType": {
                  "sys": {
                    "type": "Link",
                    "linkType": "ContentType",
                    "id": "product"
                  }
                }
              },
              "fields": {
                "name": {
                  "en-US": "Fiz"
                }
              }
            },
            {
              "metadata": {
                "tags": [],
                "concepts": []
              },
              "sys": {
                "space": {
                  "sys": {
                    "type": "Link",
                    "linkType": "Space",
                    "id": "tqsqhc19q5j2"
                  }
                },
                "id": "1dDexhBlfHfKrJnAgDOZPV",
                "type": "Entry",
                "createdAt": "2024-11-12T10:17:30.352Z",
                "updatedAt": "2024-11-12T10:17:30.352Z",
                "environment": {
                  "sys": {
                    "id": "master",
                    "type": "Link",
                    "linkType": "Environment"
                  }
                },
                "publishedVersion": 2,
                "revision": 1,
                "contentType": {
                  "sys": {
                    "type": "Link",
                    "linkType": "ContentType",
                    "id": "product"
                  }
                }
              },
              "fields": {
                "name": {
                  "en-US": "Bar"
                }
              }
            }
          ],
          "nextSyncUrl": "https://cdn.contentful.com/spaces/tqsqhc19q5j2/environments/master/sync?sync_token=FEnChMOBwr1Yw4TCqsK2LcKpCH3CjsORI8KGIUJqw6HDpsOHTMKUw7vDt2Azw6PCq8OAwozCqlVSWsKRwq7CtMK4wqfCuGNUUMO3WDoNaMO8AcOFw5nCh8O3w48cwqDCpkvDnMK0w5QCwpxKw6XDhgbDmxl4SsK7Z1HDtgk"
        }
        """.data(using: .utf8)!
    }

    static var contentTypes: Data {
        """
        {
          "sys": {
            "type": "Array"
          },
          "total": 1,
          "skip": 0,
          "limit": 100,
          "items": [
            {
              "sys": {
                "space": {
                  "sys": {
                    "type": "Link",
                    "linkType": "Space",
                    "id": "tqsqhc19q5j2"
                  }
                },
                "id": "product",
                "type": "ContentType",
                "createdAt": "2024-11-12T09:28:03.362Z",
                "updatedAt": "2024-11-12T10:27:00.096Z",
                "environment": {
                  "sys": {
                    "id": "master",
                    "type": "Link",
                    "linkType": "Environment"
                  }
                },
                "revision": 8
              },
              "displayField": "name",
              "name": "Product",
              "description": "",
              "fields": [
                {
                  "id": "name",
                  "name": "Name",
                  "type": "Symbol",
                  "localized": false,
                  "required": true,
                  "disabled": false,
                  "omitted": false
                },
                {
                  "id": "relatedProducts",
                  "name": "Related Products",
                  "type": "Array",
                  "localized": false,
                  "required": false,
                  "disabled": false,
                  "omitted": false,
                  "items": {
                    "type": "Link",
                    "validations": [],
                    "linkType": "Entry"
                  }
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!
    }
}
