//
//  Operators.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 14/04/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

func += <KeyType, ValueType>(left: inout Dictionary<KeyType, ValueType>, right: Dictionary<KeyType, ValueType>) {
    for (k, v) in right {
        left.updateValue(v, forKey: k)
    }
}

func - <T>(left: [T], right: [T]) -> [T] where T: Equatable {
    return left.filter { !right.contains($0) }
}

func valueFor<T>(_ dictionary: [String: T], keyPath: String) -> T? {
    let components = keyPath.split(".")

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

    if let dictionary = value as? [String: Any] {
        return valueFor(dictionary, keyPath: newKeyPath) as? T
    }

    if let dictionary = value as? [String: AnyObject] {
        return valueFor(dictionary, keyPath: newKeyPath) as? T
    }

    return nil
}

extension String {
    func split(_ separator: Character) -> [String] {
        return self.characters.split(separator: separator).map { String.init($0) }
    }
}
