import Defaults
import XCTest

@testable import Leader_Key

final class AppearanceTests: XCTestCase {
  func testGlassTintRawValues() {
    XCTAssertEqual(
      GlassTint.allCases.map(\.rawValue),
      ["none", "blue", "purple", "green", "pink", "orange"])
  }

  func testGlassTintDefaultsToNone() {
    XCTAssertEqual(Defaults.Keys.glassTint.defaultValue, .none)
  }

  func testGlassTintColorIsNilOnlyForNone() {
    XCTAssertNil(GlassTint.none.color)

    for tint in GlassTint.allCases where tint != .none {
      XCTAssertNotNil(tint.color)
    }
  }
}
