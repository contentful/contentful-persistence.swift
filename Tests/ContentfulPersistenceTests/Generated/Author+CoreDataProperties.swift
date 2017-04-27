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

extension Author {

    @NSManaged var biography: String?
    @NSManaged var id: String?
    @NSManaged var name: String?
    @NSManaged var website: String?
    @NSManaged var createdEntries: NSOrderedSet?
    @NSManaged var profilePhoto: Asset?

}
