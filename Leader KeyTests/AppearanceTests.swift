import Defaults
import SwiftUI
import XCTest

@testable import Leader_Key

final class AppearanceTests: XCTestCase {
  func testGlassTintColorDefaultsToClear() {
    XCTAssertEqual(Defaults.Keys.glassTintColor.defaultValue, Color.clear)
  }
}
