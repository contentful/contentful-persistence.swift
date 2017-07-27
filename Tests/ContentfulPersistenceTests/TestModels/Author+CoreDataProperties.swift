//
//  Author+CoreDataProperties.swift
//  
//
//  Created by Boris Bügling on 31/03/16.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData
import Contentful
import ContentfulPersistence

extension Author: EntryPersistable {

    static let contentTypeId = "1kUEViTN4EmGiEaaeC6ouY"

    @NSManaged var id: String
    @NSManaged var localeCode: String
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var name: String?
    @NSManaged var biography: String?
    @NSManaged var website: String?
    @NSManaged var createdEntries: NSOrderedSet?
    @NSManaged var profilePhoto: Asset?

    static func fieldMapping() -> [FieldName: String] {
        return [
            "name": "name",
            "biography": "biography",
            "website": "website",
            "createdEntries": "createdEntries",
            "profilePhoto": "profilePhoto"
        ]
    }
}
