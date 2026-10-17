import XCTest

/// Taps through the main screens and attaches a screenshot of each, for a quick visual check.
@MainActor
final class WalkthroughTests: XCTestCase {
    func testWalkthrough() throws {
        let app = XCUIApplication()
        app.launch()
        snap(app, "1-home")

        XCTAssertTrue(app.buttons["In Progress"].isSelected, "In Progress is the default view")

        // Open the first piece and advance it one stage.
        app.buttons.matching(identifier: "pieceCell").firstMatch.tap()
        snap(app, "2-detail")
        let advance = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Advance to'")).firstMatch
        if !advance.isHittable { app.swipeUp() }
        advance.tap()
        snap(app, "3-advanced")
        app.navigationBars.buttons.firstMatch.tap()

        // Switch to Ideas, then Done.
        app.buttons["Ideas"].tap()
        snap(app, "4a-ideas")
        app.buttons["Done"].tap()
        snap(app, "4b-done")

        // Open a finished piece with several photos.
        let butter = app.staticTexts["Butter Dish and Lid for Fiona and Jamie"]
        if butter.exists { butter.tap(); snap(app, "5-multi-photo"); app.navigationBars.buttons.firstMatch.tap() }

        // Search.
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("vase")
        snap(app, "6-search")
    }

    func testMerge() throws {
        let app = XCUIApplication()
        app.launch()
        // Use the last piece in the grid (a Bisqueware bowl) so ideas aren't touched.
        for _ in 0..<15 { app.swipeUp() }
        app.buttons.matching(identifier: "pieceCell").allElementsBoundByIndex.last { $0.isHittable }?.tap()
        snap(app, "m1-before")
        app.buttons["More"].tap()
        app.buttons["Merge with Another Piece…"].tap()
        snap(app, "m2-sheet")
        let candidates = app.buttons.matching(identifier: "pickerCandidate")
        candidates.element(boundBy: candidates.count - 1).tap()
        snap(app, "m3-confirm")
        app.alerts.buttons["Continue"].tap()
        sleep(1)
        snap(app, "m4-after")
        // The kept piece now shows a photo counter ("n of m"), so photos were combined.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label MATCHES '\\\\d+ of \\\\d+'")).count > 0)
    }

    func testMovePhotoToNewPiece() throws {
        let app = XCUIApplication()
        app.launch()
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("Pinched")
        app.buttons.matching(identifier: "pieceCell").firstMatch.tap()

        let counter = NSPredicate(format: "label MATCHES '\\\\d+ of \\\\d+'")
        let before = app.staticTexts.matching(counter).firstMatch.label
        snap(app, "p1-before")

        let photo = app.images.matching(identifier: "piecePhoto").allElementsBoundByIndex.last { $0.isHittable }
        photo?.press(forDuration: 1.2)
        snap(app, "p2-menu")
        app.buttons["Move to New Piece"].tap()
        sleep(1)
        snap(app, "p3-after")

        let total = { (label: String) in Int(label.split(separator: " ").last ?? "") ?? 0 }
        let after = app.staticTexts.matching(counter).firstMatch
        let afterTotal = after.exists ? total(after.label) : 1
        XCTAssertEqual(afterTotal, total(before) - 1, "one photo should have moved out")
        // The piece drops back to the stage of its furthest remaining photo.
        XCTAssertTrue(app.buttons["Stage"].label.contains("Greenware") || app.staticTexts["Bone dry and fragile, waiting for the bisque firing."].exists)
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        // The simulator shares the Mac's disk, so screenshots can go straight to a folder.
        guard let folder = ProcessInfo.processInfo.environment["SHOTS_DIR"] else { return }
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: folder).appending(path: name + ".png"))
    }
}
