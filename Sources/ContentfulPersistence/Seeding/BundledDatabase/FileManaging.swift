//
//  FileManaging.swift
//  ContentfulPersistence
//
//  Created by Marius Kurgonas on 30/05/2025.
//  Copyright © 2025 Contentful GmbH. All rights reserved.
//

import Foundation

/// Abstracts file I/O so you can inject a fake in tests.
public protocol FileManaging {
    func fileExists(atPath path: String) -> Bool
    func removeItem(at url: URL) throws
    func createDirectory(at url: URL,
                         withIntermediateDirectories createIntermediates: Bool,
                         attributes: [FileAttributeKey: Any]?) throws
    func copyItem(at src: URL, to dst: URL) throws
}

extension FileManager: FileManaging {}
