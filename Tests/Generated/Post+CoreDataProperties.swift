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

extension Post {

    @NSManaged var body: String?
    @NSManaged var comments: NSNumber?
    @NSManaged var date: NSDate?
    @NSManaged var identifier: String?
    @NSManaged var slug: String?
    @NSManaged var tags: NSData?
    @NSManaged var title: String?
    @NSManaged var author: NSOrderedSet?
    @NSManaged var category: NSOrderedSet?
    @NSManaged var featuredImage: Asset?

}
