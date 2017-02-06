//
//  BasicTests.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 17/04/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

import Nimble
import Quick

@testable import ContentfulPersistence

class BasicTests: ContentfulPersistenceTestBase {
    override func spec() {
        it("can retrieve values by keyPath") {
            let expected = ("fields.file.url", "https://yolo.com")
            let urlDict: [String: Any] = ["url": expected.1]
            let fileDict: [String: Any] = ["file": urlDict]
            let dict: [String: Any] = ["fields": fileDict]

            let value = dict.value(forKeyPath: expected.0)

            expect(value as? String).to(equal(expected.1))
        }
    }
}
