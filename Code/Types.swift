//
//  Types.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 14/04/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

public protocol Asset: Resource {
    var url: String? { get set }
}

public protocol Resource {
    var identifier: String? { get set }
}

public protocol Space {
    var syncToken: String? { get set }
}
