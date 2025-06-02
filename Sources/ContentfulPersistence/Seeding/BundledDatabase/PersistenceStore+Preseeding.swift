//
//  PreseedableStore.swift
//  ContentfulPersistence
//
//  Created by Marius Kurgonas on 30/05/2025.
//  Copyright © 2025 Contentful GmbH. All rights reserved.
//

import Foundation

public extension PersistenceStore {
    /// Default: no-op. Override to remove side-car files, reset contexts, and remove the store.
    func onStorePreseedingWillBegin(at storeFileURL: URL) throws { }
    /// Default: no-op. Override to re-add or re-open the store.
    func onStorePreseedingCompleted(at seededFileURL: URL) throws { }
}
