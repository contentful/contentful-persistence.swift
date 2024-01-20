//
//  ContentfulPersistence
//

struct RelationshipChildId: RawRepresentable, Codable, Equatable {

    typealias RawValue = String

    let rawValue: RawValue

    /// Id without locale code.
    let id: String

    /// Locale code associated with the id.
    let localeCode: String?

    init(rawValue: String) {
        self.rawValue = rawValue
        (self.id, self.localeCode) = rawValue.splitToIdAndLocaleCode()
    }

    init(id: String, localeCode: String?) {
        self.rawValue = [id, localeCode]
            .compactMap { $0 }
            .joined(separator: "_")

        self.id = id
        self.localeCode = localeCode
    }
}

private extension String {

    func splitToIdAndLocaleCode() -> (String, String?) {

        if let index = self.firstIndex(of: "_") {
            let localeCodeStartIndex = self.index(index, offsetBy: 1)
            return (String(self[self.startIndex..<index]), String(self[localeCodeStartIndex..<self.endIndex]))
        } else {
            return (self, nil)
        }
    }
}
