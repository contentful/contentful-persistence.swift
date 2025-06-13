//
//  CoreDataStore+Preseeding.swift
//  ContentfulPersistence
//
//  Created by Marius Kurgonas on 30/05/2025.
//  Copyright © 2025 Contentful GmbH. All rights reserved.
//

import CoreData

extension CoreDataStore {
    /// Before swapping: delete WAL/SHM side-cars and remove only the store matching `storeFileURL`.
    public func onStorePreseedingWillBegin(at storeFileURL: URL) throws {
        let fm = FileManager.default

        // 1) Delete WAL & SHM side-cars if they exist
        let wal = URL(fileURLWithPath: storeFileURL.path + "-wal")
        let shm = URL(fileURLWithPath: storeFileURL.path + "-shm")
        [wal, shm].forEach { url in
            if fm.fileExists(atPath: url.path) {
                try? fm.removeItem(at: url)
            }
        }

        // 2) Find and remove only the persistent store whose URL equals `storeFileURL`
        guard let coord = context.persistentStoreCoordinator else { return }
        if let psToRemove = coord.persistentStores.first(where: { $0.url == storeFileURL }) {
            try coord.remove(psToRemove)
        }
    }

    /// After swapping: add the store back *and then* reset the context.
    public func onStorePreseedingCompleted(at seededFileURL: URL) throws {
        guard let coord = context.persistentStoreCoordinator else { return }
        let options = coord.persistentStores.first?.options

        // 1) Re-add the SQLite store at the new URL
        try coord.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: seededFileURL,
            options: options
        )

        // 2) Now flush any in-memory objects so we start fresh
        context.performAndWait {
            context.reset()
        }
    }
}
