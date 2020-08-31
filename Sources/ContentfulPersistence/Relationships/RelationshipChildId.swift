//
//  ContentfulPersistence
//

struct RelationshipChildId: Codable, Equatable {

    /// Id of entry that may include locale code.
    let value: String

    /// Id without locale code.
    let id: String

    /// Locale code associated with the id.
    let localeCode: String?

    init(value: String) {
        self.value = value
        (self.id, self.localeCode) = value.splitToIdAndLocaleCode()
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
