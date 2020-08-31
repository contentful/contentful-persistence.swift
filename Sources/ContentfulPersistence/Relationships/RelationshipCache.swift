//
//  ContentfulPersistence
//

import Foundation

/**
    Stores all relationships in the database. It acts like a backup for relationships in case an entry has been
    unpublished and is published in the future.

    With this class the library can bring back a relationship on the Core Data Model level. Otherwise, in the
    following scenario, the model would not reflect a correct state of the model.

    Scenario:
    1) Fetch all data.
    2) Unpublish entry that is referenced by other entry.
    3) See the unpublished entry reference is represented by `nil` in Core Data. Relationship is `nil`.
    4) Publish entry again.
    5) See the relationship is broken. The reference is still `nil`. instead of the published entry.
 */
final class RelationshipCache {

    private let cacheFileName: String

    // Backing storage for the relationships.
    private var _relationships = [Relationship]()

    init(cacheFileName: String) {
        self.cacheFileName = cacheFileName
    }

    var relationships: [Relationship] {
        if _relationships.isEmpty {
            _relationships = loadFromCache()
        }
        return _relationships
    }

    func add(relationship: Relationship) {
        _relationships.append(relationship)
    }

    func delete(parentId: String) {
        _relationships = _relationships.filter { relationship in
            switch relationship {
            case .toOne(let nested):
                return nested.parentId != parentId
            case .toMany(let nested):
                return nested.parentId != parentId
            }
        }
    }

    func delete(parentId: String, fieldName: String, localeCode: String?) {
        _relationships = _relationships.filter { relationship in
            switch relationship {
            case .toOne(let nested):
                return !(nested.parentId == parentId
                    && nested.fieldName == fieldName
                    && nested.childId.localeCode == localeCode
                )
            case .toMany(let nested):
                /// All childs in the relationship have the same locale code.
                return !(nested.parentId == parentId
                    && nested.fieldName == fieldName
                    && nested.childIds.first?.localeCode == localeCode
                )
            }
        }
    }

    func save() {
        do {
            guard let localUrl = cacheUrl() else { return }

            let array = try _relationships.compactMap { try JSONEncoder().encode($0) }
            let data = NSKeyedArchiver.archivedData(withRootObject: array)
            try data.write(to: localUrl)
        } catch let error {
            print("Couldn't persist relationships: \(error)")
        }
    }

    private func cacheUrl() -> URL? {
        guard let url = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }

        return url.appendingPathComponent(cacheFileName)
    }

    private func loadFromCache() -> [Relationship] {
        guard let localURL = cacheUrl(),
            let data = try? Data(contentsOf: localURL, options: []),
            let array = NSKeyedUnarchiver.unarchiveObject(with: data) as? [Data]
        else { return [] }

        return (try? array.compactMap { try JSONDecoder().decode(Relationship.self, from: $0) }) ?? []
    }
}
