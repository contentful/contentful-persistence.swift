//
//  Operators.swift
//  ContentfulPersistence
//
//  Created by Boris Bügling on 14/04/16.
//  Copyright © 2016 Contentful GmbH. All rights reserved.
//

func +<K: Hashable, V> (left: Dictionary<K, V>, right: Dictionary<K, V>) -> Dictionary<K, V> {
    var result = left
    right.forEach { (key, value) in result[key] = value }
    return result
}


protocol StringProtocol {}
extension String: StringProtocol {}

extension Dictionary where Key: StringProtocol {

    func value(forKeyPath keyPath: Key) -> Value? {

        guard let components = (keyPath as? String)?.components(separatedBy: ".") else { return nil }

        switch components.count {
        case 0: return nil
        case 1: return self[keyPath]
        default: break
        }

        guard let newKeyPath = components.dropFirst().joined(separator: ".") as? Key else { return nil }
        let value = self[components[0] as! Key]

        if let innerDictionary = value as? Dictionary<Key, Any> {
            return innerDictionary.value(forKeyPath: newKeyPath) as? Value
        }
        if let innerDictionary = value as? Dictionary<Key, AnyObject> {
            return innerDictionary.value(forKeyPath: newKeyPath) as? Value
        }
        return nil
    }
}
