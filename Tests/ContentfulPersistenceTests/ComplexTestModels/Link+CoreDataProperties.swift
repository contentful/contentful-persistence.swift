//
//  Link+CoreDataProperties.swift
//  ContentfulPersistence
//
//  Created by JP Wright on 13.07.17.
//  Copyright © 2017 Contentful GmbH. All rights reserved.
//

import Foundation
import CoreData
import ContentfulPersistence

extension Link: EntryPersistable {

    static let contentTypeId = "link"

    @NSManaged var id: String
    @NSManaged var awesomeLinkTitle: String?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
}
