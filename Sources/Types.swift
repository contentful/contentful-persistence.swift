//
//  Types.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 14/04/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

import Foundation

/// Protocol for mapping Assets
@objc public protocol Asset: Resource {
    /// URL of the Asset
    var url: String? { get set }
}

/// Protocol for mapping resources
@objc public protocol Resource {
    /// ID of the resource
    var identifier: String? { get set }
}

/// Protocol for mapping Spaces
@objc public protocol Space {
    /// The current synchronization token
    var syncToken: String? { get set }
}
