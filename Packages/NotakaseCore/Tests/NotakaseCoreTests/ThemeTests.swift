import XCTest

@testable import NotakaseCore

final class ThemeTests: XCTestCase {
    func testEveryThemeNameHasAPalette() {
        for name in ThemeName.allCases {
            XCTAssertNotNil(Theme.all[name], "missing palette for \(name)")
            XCTAssertEqual(Theme.named(name).name, name)
        }
    }

    func testOrderCoversAllThemes() {
        XCTAssertEqual(Set(Theme.order), Set(ThemeName.allCases))
        XCTAssertEqual(Theme.order.count, ThemeName.allCases.count)
    }

    func testThemesPortedFromTodarchyExist() {
        // The five palettes added from the todo app.
        for name in [ThemeName.ubuntu, .osakaJade, .catppuccinLatte, .pulsar, .archwave] {
            XCTAssertNotNil(Theme.all[name])
        }
        // Latte is the only light palette.
        XCTAssertFalse(Theme.named(.catppuccinLatte).isDark)
        XCTAssertTrue(Theme.named(.tokyonight).isDark)
    }

    func testHexParsingProducesNonDefaultColors() {
        // A malformed hex would collapse to black; spot-check a known accent.
        XCTAssertEqual(Theme.named(.ubuntu).accent, "#e95420")
    }
}
