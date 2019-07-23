//
//  RichTextDocumentTransformableTests.swift
//  ContentfulPersistence
//
//  Created by Manuel Maly on 23.07.19.
//  Copyright © 2019 Contentful GmbH. All rights reserved.
//


@testable import ContentfulPersistence
import Contentful
import XCTest
import Foundation
import CoreData

class RichTextDocumentTransformableTests: XCTestCase {

    lazy var store: CoreDataStore = {
        return CoreDataStore(context: self.managedObjectContext)
    }()

    lazy var managedObjectContext: NSManagedObjectContext = {
        return TestHelpers.managedObjectContext(forMOMInTestBundleNamed: "RichTextDocumentTransformableTest")
    }()

    override func tearDown() {
        try? store.delete(type: RichTextDocumentRecord.self, predicate: NSPredicate(value: true))
    }

    func testRichTextDocumentPersistence() {

        guard let richTextDocumentRecord: RichTextDocumentRecord = try? store.create(type: RichTextDocumentRecord.self) else {
            XCTFail()
            return
        }

        let document = richTextDocument()
        richTextDocumentRecord.richTextDocument = document

        try? store.save()
        managedObjectContext.refresh(richTextDocumentRecord, mergeChanges: false)

        XCTAssertEqual(richTextDocumentRecord.richTextDocument?.content.count ?? 0, document.content.count)
    }

    private func richTextDocument() -> RichTextDocument {
        let paragraphText1: Text = {
            return Text(value: "paragraphText1", marks: [])
        }()

        let paragraphText2: Text = {
            return Text(value: "paragraphText2", marks: [])
        }()

        let paragraph = Paragraph(nodeType: .paragraph, content: [paragraphText1, paragraphText2])

        let headingText: Text = {
            let bold = Text.Mark(type: Text.MarkType.bold)
            let italic = Text.Mark(type: Text.MarkType.italic)
            return Text(value: "headingText", marks: [bold, italic])
        }()

        let headingH1 = Heading(level: 1, content: [headingText])!
        let headingH2 = Heading(level: 2, content: [headingText])! // test copy of headingText


        let blockQuoteText: Text = {
            let code = Text.Mark(type: Text.MarkType.code)
            return Text(value: "blockQuoteText", marks: [code])
        }()
        let blockQuote = BlockQuote(nodeType: NodeType.blockquote, content: [blockQuoteText])

        let horizontalRule = HorizontalRule(nodeType: NodeType.horizontalRule, content: [])

        let listItem1 = ListItem(nodeType: .listItem, content: [paragraphText1])
        let listItem2 = ListItem(nodeType: .listItem, content: [paragraphText2])
        let listItem3 = ListItem(nodeType: .listItem, content: [paragraph])
        let orderedList = OrderedList(nodeType: .orderedList, content: [listItem1, listItem2, listItem3])

        // Use listItem2 twice:
        let unorderedList = OrderedList(nodeType: .orderedList, content: [listItem1, listItem2, listItem2])

        let link = Contentful.Link
            .unresolved(Contentful.Link.Sys(id: "unlinked-entry", linkType: "Entry", type: "Entry"))
        let embeddedAssetBlock = ResourceLinkBlock(
            resolvedData: ResourceLinkData(resolvedTarget: link, title: "linkTitle"),
            nodeType: NodeType.embeddedAssetBlock,
            content: []
        )

        let hyperlink = Hyperlink(
            data: Hyperlink.Data(uri: "https://contentful.com", title: "Contentful"),
            content: []
        )

        return RichTextDocument(
            content: (
                [
                    paragraphText1,
                    paragraph,
                    headingH1,
                    headingH2,
                    blockQuote,
                    horizontalRule,
                    orderedList,
                    unorderedList,
                    embeddedAssetBlock,
                    hyperlink
                    ] as [Node?] // compiler needs this cast
                ).compactMap { $0 }
        )
    }

}
