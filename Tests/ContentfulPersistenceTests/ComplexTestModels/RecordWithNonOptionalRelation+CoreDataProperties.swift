//
//  RecordWithNonOptionalRelation+CoreDataProperties.swift
//  ContentfulPersistence
//
//  Created by Manuel Maly on 28.06.19.
//  Copyright © 2019 Contentful GmbH. All rights reserved.
//

import Foundation
import CoreData
import Contentful
import ContentfulPersistence

extension RecordWithNonOptionalRelation: EntryPersistable {

    static let contentTypeId = "recordWithNonOptionalRelation"

    @NSManaged var id: String
    @NSManaged var localeCode: String?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var nonOptionalLink: Link

    static func fieldMapping() -> [FieldName: String] {
        return [
            "nonOptionalLink": "nonOptionalLink"
        ]
    }
}
