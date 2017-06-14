//
//  SyncInfo+CoreDataProperties.swift
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

extension SyncInfo: SyncSpacePersistable {

    @NSManaged var lastSyncTimestamp: Date?
    @NSManaged var syncToken: String?
}
