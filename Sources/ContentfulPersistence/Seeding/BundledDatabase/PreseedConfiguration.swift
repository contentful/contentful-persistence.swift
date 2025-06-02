//
//  PreseedConfiguration.swift
//  ContentfulPersistence
//
//  Created by Marius Kurgonas on 30/05/2025.
//  Copyright © 2025 Contentful GmbH. All rights reserved.
//

import Foundation

/// Describes a bundled seed and the exact directory on disk where
/// `<resourceName>.<resourceExtension>` will be placed.
public struct PreseedConfiguration {
    /// e.g. "SeedDB" (no “.sqlite”)
    public let resourceName: String

    /// e.g. "sqlite"
    public let resourceExtension: String

    /// Optional bundle subfolder
    public let subdirectory: String?

    /// Bundle containing the resource (default: .main)
    public let bundle: Bundle

    /// Directory on disk where the main `.sqlite` lives. **Required.**
    public let sqliteContainerPath: URL
    
    /// The version that this bundled seed represents.
        public let dbVersion: Int

    /// - Parameters:
    ///   - resourceName: Base name of the bundle file.
    ///   - resourceExtension: Extension (e.g. "sqlite").
    ///   - subdirectory: Bundle subfolder (nil = top).
    ///   - bundle: The bundle containing it.
    ///   - overrideStoreDirectory: On-disk folder to wipe & seed.
    ///   - dbVersion: The migration version for this seed.
    public init(resourceName: String,
                resourceExtension: String,
                subdirectory: String? = nil,
                bundle: Bundle = .main,
                sqliteContainerPath: URL,
                dbVersion: Int) {
        self.resourceName           = resourceName
        self.resourceExtension      = resourceExtension
        self.subdirectory           = subdirectory
        self.bundle                 = bundle
        self.sqliteContainerPath = sqliteContainerPath
        self.dbVersion              = dbVersion
    }
}
