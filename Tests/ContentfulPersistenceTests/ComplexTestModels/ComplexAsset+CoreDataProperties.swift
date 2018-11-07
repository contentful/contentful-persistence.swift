//
//  ComplexAsset+CoreDataProperties.swift
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
import Contentful
import ContentfulPersistence

extension ComplexAsset: AssetPersistable {

    // FlatResource
    @NSManaged var id: String
    @NSManaged var localeCode: String?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?

    // AssetPersistable
    @NSManaged var title: String?
    @NSManaged var assetDescription: String?
    @NSManaged var urlString: String?
    @NSManaged var fileType: String?
    @NSManaged var fileName: String?

    @NSManaged var size: NSNumber?
    @NSManaged var width: NSNumber?
    @NSManaged var height: NSNumber?
}
