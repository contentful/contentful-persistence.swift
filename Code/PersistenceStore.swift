//
//  PersistenceStore.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 30/03/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

import Foundation

/// Protocol for persistence stores used by `ContentfulSynchronizer`
public protocol PersistenceStore {
    /**
     Create a new object of the given type.

     - parameter type: The type of which a new object should be created

     - throws: If a invalid type was specified

     - returns: A newly created object of the given type
     */
    func create<T>(type: Any.Type) throws -> T

    /**
     Delete objects of the given type which also match the predicate.

     - parameter type:      The type of which objects should be deleted
     - parameter predicate: The predicate used for matching objects to delete

     - throws: If an invalid type was specified
     */
    func delete(type: Any.Type, predicate: NSPredicate) throws

    /**
     Fetches all objects of a specific type which also match the predicate.

     - parameter type:      The type of which objects should be fetched
     - parameter predicate: The predicate used for matching object to fetch

     - throws: If an invalid type was specified

     - returns: An array of matching objects
     */
    func fetchAll<T>(type: Any.Type, predicate: NSPredicate) throws -> [T]

    /**
     Returns an array of names of properties the given type stores persistently.

     This should omit any properties returned by `relationshipsFor(type:)`.

     - parameter type: The type of which properties should be returned for

     - throws: If an invalid type was specified

     - returns: An array of property names
     */
    func propertiesFor(type type: Any.Type) throws -> [String]

    /**
     Returns an array of names of properties for any relationship the given type stores persistently.

     - parameter type: The type of which properties should be returned for

     - throws: If an invalid type was specified

     - returns: An array of property names
     */
    func relationshipsFor(type type: Any.Type) throws -> [String]

    /**
     Performs the actual save to the persistence store.

     - throws: If any error occured during the save operation
     */
    func save() throws
}
