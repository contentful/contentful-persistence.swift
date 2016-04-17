//
//  CoreDataStore.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 31/03/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

import CoreData

enum Errors: ErrorType {
    case InvalidType(type: Any.Type)
}

public class CoreDataStore : PersistenceStore {
    private let context: NSManagedObjectContext

    public init(context: NSManagedObjectContext) {
        self.context = context
    }

    public func create<T>(type: Any.Type) throws -> T {
        var type = type

        if let `class` = type as? AnyClass {
            let object = NSEntityDescription.insertNewObjectForEntityForName(NSStringFromClass(`class`), inManagedObjectContext: context)

            if let object = object as? T {
                return object
            } else {
                type = object.dynamicType
            }
        }

        throw Errors.InvalidType(type: type)
    }

    public func delete(type: Any.Type, predicate: NSPredicate) throws {
        let objects: [NSManagedObject] = try fetchAll(type, predicate: predicate)
        objects.forEach {
            self.context.deleteObject($0)
        }
    }

    public func fetchAll<T>(type: Any.Type, predicate: NSPredicate) throws -> [T] {
        if let `class` = type as? AnyClass {
            let request = NSFetchRequest(entityName: NSStringFromClass(`class`))
            request.predicate = predicate
            return try context.executeFetchRequest(request).flatMap { $0 as? T }
        }
        
        throw Errors.InvalidType(type: type)
    }

    public func propertiesFor(type type: Any.Type) throws -> [String] {
        let description = try entityDescriptionFor(type: type)
        return try description.propertiesByName.map { $0.0 } - relationshipsFor(type: type)
    }

    public func relationshipsFor(type type: Any.Type) throws -> [String] {
        let description = try entityDescriptionFor(type: type)
        return description.relationshipsByName.map { $0.0 }
    }

    public func save() throws {
        try context.save()
    }

    // MARK: - Helper methods

    private func entityDescriptionFor(type type: Any.Type) throws -> NSEntityDescription {
        if let `class` = type as? AnyClass, description = NSEntityDescription.entityForName(NSStringFromClass(`class`), inManagedObjectContext: context) {
            return description
        }

        throw Errors.InvalidType(type: type)
    }
}
