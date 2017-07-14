//
//  Post+CoreDataProperties.swift
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
import ContentfulPersistence
import Contentful

extension Post: EntryPersistable {
    
    static let contentTypeId = "2wKn6yEnZewu2SCCkus4as"

    @NSManaged var id: String
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var body: String?
    @NSManaged var comments: NSNumber?
    @NSManaged var date: NSDate?
    @NSManaged var slug: String?
    @NSManaged var tags: Data?
    @NSManaged var title: String?
    @NSManaged var author: NSOrderedSet?
    @NSManaged var category: NSOrderedSet?
    @NSManaged var theFeaturedImage: Asset?

    static func mapping() -> [FieldName: String] {
        return [
            "title": "title",
            "featuredImage": "theFeaturedImage"
        ]
    }
}
