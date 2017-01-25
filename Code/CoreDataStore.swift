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

/// Implementation fo the `PersistenceStore` protocol using CoreData
public class CoreDataStore : PersistenceStore {
    private let context: NSManagedObjectContext

    /**
     Initialize a new CoreData persistence store

     - parameter context: The managed object context used for querying and

     - returns: An initialised instance of this class
     */
    public init(context: NSManagedObjectContext) {
        self.context = context
    }

    public func fetchRequest(type: Any.Type, predicate: NSPredicate) throws -> NSFetchRequest {
        if let `class` = type as? AnyClass {
            let request = NSFetchRequest(entityName: NSStringFromClass(`class`))
            request.predicate = predicate
            return request
        }

        throw Errors.InvalidType(type: type)
    }

    // MARK: <PersistenceStore>

    /**
     Create a new object of the given type.

     - parameter type: The type of which a new object should be created

     - throws: If a invalid type was specified

     - returns: A newly created object of the given type
     */
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

    /**
     Delete objects of the given type which also match the predicate.

     - parameter type:      The type of which objects should be deleted
     - parameter predicate: The predicate used for matching objects to delete

     - throws: If an invalid type was specified
     */
    public func delete(type: Any.Type, predicate: NSPredicate) throws {
        let objects: [NSManagedObject] = try fetchAll(type, predicate: predicate)
        objects.forEach {
            self.context.deleteObject($0)
        }
    }

    /**
     Fetches all objects of a specific type which also match the predicate.

     - parameter type:      The type of which objects should be fetched
     - parameter predicate: The predicate used for matching object to fetch

     - throws: If an invalid type was specified

     - returns: An array of matching objects
     */
    public func fetchAll<T>(type: Any.Type, predicate: NSPredicate) throws -> [T] {
        let request = try fetchRequest(type, predicate: predicate)
        return try context.executeFetchRequest(request).flatMap { $0 as? T }
    }

    /**
     Returns an array of names of properties the given type stores persistently.

     This should omit any properties returned by `relationshipsFor(type:)`.

     - parameter type: The type of which properties should be returned for

     - throws: If an invalid type was specified

     - returns: An array of property names representing system native types.
     */
    public func propertiesFor(type type: Any.Type) throws -> [String] {
        let description = try entityDescriptionFor(type: type)
        return try description.propertiesByName.map { $0.0 } - relationshipsFor(type: type)
    }

    /**
     Returns an array of property names for any relationship the given type stores persistently.

     - parameter type: The type of which properties should be returned for

     - throws: If an invalid type was specified

     - returns: An array of property names representing related entities.
     */
    public func relationshipsFor(type type: Any.Type) throws -> [String] {
        let description = try entityDescriptionFor(type: type)
        return description.relationshipsByName.map { $0.0 }
    }

    /**
     Performs the actual save to the persistence store.

     - throws: If any error occured during the save operation
     */
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
