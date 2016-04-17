//
//  PersistenceStore.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 30/03/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

import Foundation

public protocol PersistenceStore {
    func create<T>(type: Any.Type) throws -> T

    func delete(type: Any.Type, predicate: NSPredicate) throws

    func fetchAll<T>(type: Any.Type, predicate: NSPredicate) throws -> [T]

    func propertiesFor(type type: Any.Type) throws -> [String]

    func relationshipsFor(type type: Any.Type) throws -> [String]

    func save() throws
}
