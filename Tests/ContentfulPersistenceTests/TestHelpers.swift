//
//  TestHelpers.swift
//  ContentfulPersistence
//
//  Created by JP Wright on 12.07.17.
//  Copyright © 2017 Contentful GmbH. All rights reserved.
//

import Foundation

class TestHelpers {

    static func jsonData(_ fileName: String) -> [String: Any] {
        let bundle = Bundle(for: TestHelpers.self)
        let urlPath = bundle.path(forResource: fileName, ofType: "json")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: urlPath))
        return try! JSONSerialization.jsonObject(with: data, options: []) as! [String : Any]
    }
}
