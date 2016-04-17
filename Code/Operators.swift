//
//  Operators.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 14/04/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

func += <KeyType, ValueType> (inout left: Dictionary<KeyType, ValueType>, right: Dictionary<KeyType, ValueType>) {
    for (k, v) in right {
        left.updateValue(v, forKey: k)
    }
}

func - <T: Equatable> (left: [T], right: [T]) -> [T] {
    return left.filter { !right.contains($0) }
}

func valueFor<T>(dictionary: [String: T], keyPath: String) -> T? {
    let components = keyPath.split(".")

    switch components.count {
    case 0:
        return nil
    case 1:
        return dictionary[keyPath]
    default:
        break
    }

    let newKeyPath = components.dropFirst().joinWithSeparator(".")
    let value = dictionary[components[0]]

    if let dictionary = value as? [String: Any] {
        return valueFor(dictionary, keyPath: newKeyPath) as? T
    }

    if let dictionary = value as? [String: AnyObject] {
        return valueFor(dictionary, keyPath: newKeyPath) as? T
    }

    return nil
}

extension String {
    func split(separator: Character) -> [String] {
        return self.characters.split(separator).map { String.init($0) }
    }
}
