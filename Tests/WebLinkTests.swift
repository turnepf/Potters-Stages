import Foundation
import Testing
@testable import PottersStages

/// Only http and https links get saved or opened; anything else could launch a local
/// file or another app when the inspiration link is tapped.
@MainActor
struct WebLinkTests {
    @Test(arguments: ["https://example.com/pot", "http://example.com", "HTTPS://Example.com"])
    func webLinksAreAllowed(_ text: String) {
        #expect(URL(string: text)!.isWebLink)
    }

    @Test(arguments: [
        "file://localhost/Applications/Calculator.app",
        "file:///etc/hosts",
        "shortcuts://run-shortcut?name=X",
        "tel:5551234",
        "mailto:someone@example.com",
    ])
    func otherSchemesAreRejected(_ text: String) {
        #expect(!URL(string: text)!.isWebLink)
    }

    @Test func typedLinks() {
        #expect(URL.fromUserInput("instagram.com/p/abc")?.absoluteString == "https://instagram.com/p/abc")
        #expect(URL.fromUserInput("  https://example.com  ")?.absoluteString == "https://example.com")
        #expect(URL.fromUserInput("file://localhost/Applications/Calculator.app") == nil)
        #expect(URL.fromUserInput("shortcuts://run-shortcut?name=X") == nil)
        #expect(URL.fromUserInput("") == nil)
    }

    @Test func linksInSharedText() {
        #expect(URL.firstWebLink(in: "look at this https://example.com/vase")?.absoluteString == "https://example.com/vase")
        // A non-web link first is skipped in favor of the web link after it.
        #expect(URL.firstWebLink(in: "file://localhost/Applications/Calculator.app then https://example.com")?.absoluteString == "https://example.com")
        #expect(URL.firstWebLink(in: "see file://localhost/Applications/Calculator.app") == nil)
        #expect(URL.firstWebLink(in: "call tel:5551234 or shortcuts://run-shortcut?name=X") == nil)
        #expect(URL.firstWebLink(in: "no links here") == nil)
    }
}
