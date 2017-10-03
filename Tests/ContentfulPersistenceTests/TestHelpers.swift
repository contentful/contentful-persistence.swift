//
//  TestHelpers.swift
//  ContentfulPersistence
//
//  Created by JP Wright on 12.07.17.
//  Copyright © 2017 Contentful GmbH. All rights reserved.
//

import Foundation

class TestHelpers {

    static func jsonData(_ fileName: String) -> Data {
        let bundle = Bundle(for: TestHelpers.self)
        let urlPath = bundle.path(forResource: fileName, ofType: "json")!
        return try! Data(contentsOf: URL(fileURLWithPath: urlPath))
    }
}
