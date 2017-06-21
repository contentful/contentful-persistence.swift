//
//  Asset+CoreDataProperties.swift
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

extension Asset: AssetPersistable {

    @NSManaged var id: String
    @NSManaged var title: String?
    @NSManaged var assetDescription: String?
    @NSManaged var urlString: String?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var width: NSNumber?
    @NSManaged var height: NSNumber?
    @NSManaged var internetMediaType: String?

    @NSManaged var featuredImage_2wKn6yEnZewu2SCCkus4as_Inverse: NSSet?
    @NSManaged var icon_5KMiN6YPvi42icqAUQMCQe_Inverse: NSSet?
    @NSManaged var profilePhoto_1kUEViTN4EmGiEaaeC6ouY_Inverse: NSSet?
}
