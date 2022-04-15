//
//  ComplexSyncInfo+CoreDataProperties.swift
//
//
//  Created by JP Wright on 31/03/16.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData
import ContentfulPersistence

extension ComplexSyncInfo: SyncSpacePersistable {

    @NSManaged var syncToken: String?
    
    @NSManaged var dbVersion: NSNumber?
}
