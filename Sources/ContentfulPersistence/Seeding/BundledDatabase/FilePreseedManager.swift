//
//  FilePreseedManager.swift
//  ContentfulPersistence
//
//  Created by Marius Kurgonas on 30/05/2025.
//  Copyright © 2025 Contentful GmbH. All rights reserved.
//

import Foundation

/// Default strategy that:
/// 1) calls `onStorePreseedingWillBegin(at:)`
/// 2) wipes the entire seed folder
/// 3) copies `<resourceName>.<resourceExtension>`
/// 4) calls `onStorePreseedingCompleted(at:)`
/// 5) writes back `dbVersion`
public class FilePreseedManager: PreseedStrategy {
    private let fileManager: FileManaging

    /// - Parameter fileManager: Test‐injectable; default = `FileManager.default`
    public init(fileManager: FileManaging = FileManager.default) {
        self.fileManager = fileManager
    }

    public func apply(to store: PersistenceStore,
                      with config: PreseedConfiguration,
                      spaceType: SyncSpacePersistable.Type) throws
    {
        let filename = "\(config.resourceName).\(config.resourceExtension)"
        let dbURL    = config.sqliteContainerPath.appendingPathComponent(filename)
        
        guard let seedURL = config.bundle.url(
            forResource: config.resourceName,
            withExtension: config.resourceExtension,
            subdirectory: config.subdirectory)
        else {
            throw NSError(
                domain: "ContentfulPersistence",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey:
                    "Seed file not found: \(config.resourceName).\(config.resourceExtension)"])
        }

        // Read existing version (0 if none)
        let lastVersion: Int = {
            do {
                let spaces: [SyncSpacePersistable] = try store.fetchAll(type: spaceType, predicate: NSPredicate(value: true))
                return spaces.count > 0 ? spaces[0].dbVersion?.intValue ?? 0 : 0
            } catch {
                return 0
            }
        }()

        // Only seed if fresh or version bumped
        let missing = !fileManager.fileExists(atPath: dbURL.path)
        guard missing || config.dbVersion > lastVersion else { return }

        // Prepare the store
        try store.onStorePreseedingWillBegin(at: dbURL)
    
        // Remove existing
        try? fileManager.removeItem(at: config.sqliteContainerPath)
    
        try fileManager.createDirectory(
            at: config.sqliteContainerPath,
            withIntermediateDirectories: true,
            attributes: nil
        )

        try fileManager.copyItem(at: seedURL, to: dbURL)

        // Re-open the store
        try store.onStorePreseedingCompleted(at: dbURL)
    }
}
