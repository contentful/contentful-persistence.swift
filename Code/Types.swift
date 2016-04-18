//
//  Types.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 14/04/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

/// Protocol for mapping Assets
public protocol Asset: Resource {
    /// URL of the Asset
    var url: String? { get set }
}

/// Protocol for mapping resources
public protocol Resource {
    /// ID of the resource
    var identifier: String? { get set }
}

/// Protocol for mapping Spaces
public protocol Space {
    /// The current synchronization token
    var syncToken: String? { get set }
}
