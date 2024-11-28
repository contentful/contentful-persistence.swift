import Contentful
@testable import ContentfulPersistence
import XCTest

class SynchronizationManagerSyncTests: XCTestCase {
    var sut: SynchronizationManager!
    var client: Client!
    var partialCompletion: ResultsHandler<SyncSpace>!
    var finalCompletion: ResultsHandler<SyncSpace>!

    override func setUp() {
        super.setUp()

        client = Client(
            spaceId: "spaceId",
            accessToken: "accessToken",
            sessionConfiguration: {
                let config = URLSessionConfiguration.ephemeral
                config.protocolClasses = [MockURLProtocol.self]
                return config
            }()
        )

        sut = SynchronizationManager(
            client: client,
            localizationScheme: .all,
            persistenceStore: MockPersistenceStore(),
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
            ]

        partialCompletion = { result in
            print("###", result)
            expectation.fulfill()
        }

        finalCompletion = { result in
            print("###", result)
            expectation.fulfill()
        }

        try sut
            .sync(
                syncSpacePersistable: MockSyncSpacePersistable.self,
                initialLocalizationScheme: .default,
                onInitialCompletion: partialCompletion,
                onFinalCompletion: finalCompletion
            )

        wait(for: [expectation], timeout: 5)
    }
}

extension URL {
    static var locales: URL =
        URL(string: "https://cdn.contentful.com/spaces/spaceId/environments/master/locales?limit=1000")!
    
    static var sync: URL =
        URL(string: "https://cdn.contentful.com/spaces/spaceId/environments/master/sync?initial=true")!
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
}
