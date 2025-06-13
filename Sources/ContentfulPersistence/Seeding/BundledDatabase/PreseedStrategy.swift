//
//  PreseedStrategy.swift
//  ContentfulPersistence
//
//  Created by Marius Kurgonas on 30/05/2025.
//  Copyright © 2025 Contentful GmbH. All rights reserved.
//

import Foundation

/// A hook for “seed my store from a bundled file” logic.
public protocol PreseedStrategy {
    /**
     Perform the bundle-seed.

     - Parameters:
       - store: The `PersistenceStore` to seed.
       - config: Bundled resource info + target directory + version.
       - spaceType: Your `SyncSpacePersistable` type (for reading/writing `dbVersion`).
     */
    func apply(to store: PersistenceStore,
               with config: PreseedConfiguration,
               spaceType: SyncSpacePersistable.Type) throws
}
