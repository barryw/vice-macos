import Foundation
import XCTest

final class DocumentationExamplesTests: XCTestCase {
    func testPublishedQuickStartMatchesCompiledExample() throws {
        let testSourceDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let packageRoot = testSourceDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let repositoryRoot = packageRoot.deletingLastPathComponent()

        let snippet = try Self.extractSnippet(
            named: "MacVICEKitQuickStart",
            from: testSourceDirectory.appendingPathComponent("DocumentationQuickStartExample.swift")
        )

        let requiredSources = [
            packageRoot.appendingPathComponent("README.md"),
            packageRoot.appendingPathComponent("Sources/MacVICEKit/MacVICEKit.docc/MacVICEKit.md")
        ]

        for source in requiredSources {
            let contents = try String(contentsOf: source, encoding: .utf8)
            XCTAssertTrue(
                contents.contains(snippet),
                "\(source.path) does not contain the compiled MacVICEKit quick-start example."
            )
        }

        let websitePage = repositoryRoot.appendingPathComponent("website/macvicekit.html")
        if FileManager.default.fileExists(atPath: websitePage.path) {
            let contents = try String(contentsOf: websitePage, encoding: .utf8)
            XCTAssertTrue(
                contents.contains(snippet),
                "\(websitePage.path) does not contain the compiled MacVICEKit quick-start example."
            )
        }

        let generatedDocCIndex = repositoryRoot
            .appendingPathComponent("website/docs/macvicekit/data/documentation/macvicekit.json")
        if FileManager.default.fileExists(atPath: generatedDocCIndex.path) {
            let listings = try Self.swiftCodeListings(in: generatedDocCIndex)
            XCTAssertTrue(
                listings.contains(snippet),
                "\(generatedDocCIndex.path) does not contain the compiled MacVICEKit quick-start example. Run website/tools/build-macvicekit-docs.sh."
            )
        }
    }

    private static func extractSnippet(named name: String, from url: URL) throws -> String {
        let contents = try String(contentsOf: url, encoding: .utf8)
        let beginMarker = "// BEGIN: \(name)"
        let endMarker = "// END: \(name)"

        guard let beginRange = contents.range(of: beginMarker),
              let endRange = contents.range(of: endMarker, range: beginRange.upperBound..<contents.endIndex) else {
            throw XCTSkip("Snippet markers for \(name) were not found in \(url.path).")
        }

        return String(contents[beginRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func swiftCodeListings(in url: URL) throws -> [String] {
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        return swiftCodeListings(in: object)
    }

    private static func swiftCodeListings(in object: Any) -> [String] {
        if let dictionary = object as? [String: Any] {
            var listings: [String] = []

            if dictionary["type"] as? String == "codeListing",
               dictionary["syntax"] as? String == "swift",
               let code = dictionary["code"] as? [String] {
                listings.append(code.joined(separator: "\n"))
            }

            for value in dictionary.values {
                listings.append(contentsOf: swiftCodeListings(in: value))
            }

            return listings
        }

        if let array = object as? [Any] {
            return array.flatMap(swiftCodeListings)
        }

        return []
    }
}
