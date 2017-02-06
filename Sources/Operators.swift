//
//  Operators.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 14/04/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

internal func += <KeyType, ValueType>(left: inout Dictionary<KeyType, ValueType>, right: Dictionary<KeyType, ValueType>) {
    for (k, v) in right {
        left.updateValue(v, forKey: k)
    }
}

internal func valueIn<T>(dictionary: [String: T], forKeyPath keyPath: String) -> T? {

    let components = keyPath.components(separatedBy: ".")

    switch components.count {
    case 0:
        return nil
    case 1:
        return dictionary[keyPath]
    default:
        break
    }

    let newKeyPath = components.dropFirst().joined(separator: ".")
    let value = dictionary[components[0]]

    if let innerDictionary = value as? [String: Any] {
        return ContentfulPersistence.valueIn(dictionary: innerDictionary, forKeyPath: newKeyPath) as? T
    }

    if let innerDictionary = value as? [String: AnyObject] {
        return ContentfulPersistence.valueIn(dictionary: innerDictionary, forKeyPath: newKeyPath) as? T
    }

    return nil
}
