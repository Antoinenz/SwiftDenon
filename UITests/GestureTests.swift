import XCTest

/// Drives the iPhone gestures against demo mode (no receiver needed): `xcodebuild test` with an iOS
/// simulator destination. Gestures are synthesised inside the simulator, so nothing touches the Mac.
final class GestureTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-demoMode", "YES", "-zone", "0"]
        app.launch()
        XCTAssertTrue(volumeElement.waitForExistence(timeout: 30))
    }

    private var volumeElement: XCUIElement { app.descendants(matching: .any).matching(identifier: "Volume").firstMatch }
    private var volume: Double { Double("\(volumeElement.value ?? "")") ?? -1 }

    private func point(_ x: Double, _ y: Double) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
    }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name; a.lifetime = .keepAlways
        add(a)
    }

    private var inputItem: XCUIElement { app.descendants(matching: .any)["Game Console"].firstMatch }
    private var inputListIsOpen: Bool { inputItem.waitForExistence(timeout: 2) }

    func testSwipeUpFromBottomThirdOpensInputs() throws {
        point(0.1, 0.85).press(forDuration: 0.05, thenDragTo: point(0.1, 0.5))
        XCTAssertTrue(inputListIsOpen)
        shot("inputs-open")
    }

    func testSwipeUpFromTheMiddleDoesNothing() throws {
        point(0.1, 0.45).press(forDuration: 0.05, thenDragTo: point(0.1, 0.2))
        XCTAssertFalse(inputItem.waitForExistence(timeout: 2))
    }

    /// Dragging level with the slider moves it a long way; the same sideways distance travelled
    /// while moving well below it changes the volume far less.
    func testScrubSlowsDownAwayFromTheSlider() throws {
        let y = 0.546
        let start = volume
        point(0.5, y).press(forDuration: 0.1, thenDragTo: point(0.7, y), withVelocity: .slow, thenHoldForDuration: 0.2)
        let fast = volume - start
        shot("level")
        point(0.7, y).press(forDuration: 0.1, thenDragTo: point(0.5, y + 0.25), withVelocity: .slow, thenHoldForDuration: 0.2)
        let slow = (volume - start) - fast   // negative: the drag went left
        shot("below")
        print("SCRUB level \(fast), below \(slow)")
        XCTAssertGreaterThan(fast, 10)
        XCTAssertLessThan(slow, 0)
        XCTAssertLessThan(abs(slow), fast * 0.7)
    }

    func testHoldingPlusKeepsStepping() throws {
        let start = volume
        point(0.875, 0.546).press(forDuration: 0.1)
        XCTAssertEqual(volume, start + 1, "a tap steps once")
        point(0.875, 0.546).press(forDuration: 2.5)
        print("HOLD \(volume - start - 1) extra steps")
        XCTAssertGreaterThan(volume, start + 12)
    }
}
