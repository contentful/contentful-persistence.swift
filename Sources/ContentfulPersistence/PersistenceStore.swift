//
//  PersistentStore.swift
//  ContentfulPersistence
//
//  Created by JP Wright on 16.06.17.
//  Copyright © 2017 Contentful GmbH. All rights reserved.
//

import Foundation

/// Protocol for persistence stores used by `SynchronizationManager`
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
        Fetches one object of a specific type which matches the predicate.

        - parameter type: Type of which object should be fetched.
        - parameter predicate: The predicate used for matching object to fetch.

        - throws: If an invalid type was specified

        - returns: Matching object
     */
     func fetchOne<T>(type: Any.Type, predicate: NSPredicate) throws -> T

    /**
     Returns an array of names of properties the given type stores persistently.

     This should omit any properties returned by `relationshipsFor(type:)`.

     - parameter type: The type of which properties should be returned for

     - throws: If an invalid type was specified

     - returns: An array of property names
     */
    func properties(for type: Any.Type) throws -> [String]

    /**
     Returns an array of names of properties for any relationship the given type stores persistently.

     - parameter type: The type of which properties should be returned for

     - throws: If an invalid type was specified

     - returns: An array of property names
     */
    func relationships(for type: Any.Type) throws -> [String]

    /**
     Performs the actual save to the persistence store.

     - throws: If any error occured during the save operation
     */
    func save() throws
    
    /// Deletes all the data in the database
    func wipe() throws

    func performBlock(block: @escaping () -> Void)

    func performAndWait(block: @escaping () -> Void)
    
    /// Called **before** the main `.sqlite` is swapped. Gives you the full file URL.
    func onStorePreseedingWillBegin(at storeFileURL: URL) throws
    
    /// Called **after** the main file is in place.
    func onStorePreseedingCompleted(at seededFileURL: URL) throws
}
