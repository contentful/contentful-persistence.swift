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

    init(cacheFileName: String) {
        self.cacheFileName = cacheFileName
    }

    private(set) lazy var relationships: RelationshipData = loadFromCache()

    func add(relationship: Relationship) {
        relationships.append(relationship)
    }

    func delete(parentId: String) {
        relationships.delete(parentId: parentId)
    }

    func delete(parentId: String, fieldName: String, localeCode: String?) {
        relationships.delete(parentId: parentId, fieldName: fieldName, localeCode: localeCode)
    }

    func save() {
        do {
            guard let localUrl = cacheUrl() else { return }
            let data = try JSONEncoder().encode(relationships)
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

    private func loadFromCache() -> RelationshipData {
        do {
            guard let localURL = cacheUrl() else { return .init() }
            let data = try Data(contentsOf: localURL, options: [])
            return try JSONDecoder().decode(RelationshipData.self, from: data)
        } catch {
            return .init()
        }
    }
}
