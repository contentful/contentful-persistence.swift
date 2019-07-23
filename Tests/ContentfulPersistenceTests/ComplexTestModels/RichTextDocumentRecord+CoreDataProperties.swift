//
//  RichTextDocumentRecord+CoreDataProperties.swift
//
//
//  Created by Manuel Maly on 23/07/19.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData
import Contentful
import ContentfulPersistence

extension RichTextDocumentRecord: EntryPersistable {

    static let contentTypeId = "richTextDocumentRecord"

    @NSManaged var id: String
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var localeCode: String?
    @NSManaged var richTextDocument: RichTextDocument?

    static func fieldMapping() -> [FieldName: String] {
        return [
            "richTextDocument": "richTextDocument"
        ]
    }
}
