import XCTest

@testable import Leader_Key

final class URLSchemeTests: XCTestCase {

  // MARK: - Configuration Management Tests

  func testConfigReloadURL() {
    let url = URL(string: "leaderkey://config-reload")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .configReload)
  }

  func testConfigRevealURL() {
    let url = URL(string: "leaderkey://config-reveal")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .configReveal)
  }

  // MARK: - Window Control Tests

  func testActivateURL() {
    let url = URL(string: "leaderkey://activate")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .activate)
  }

  func testHideURL() {
    let url = URL(string: "leaderkey://hide")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .hide)
  }

  func testResetURL() {
    let url = URL(string: "leaderkey://reset")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .reset)
  }

  // MARK: - Settings & Info Tests

  func testSettingsURL() {
    let url = URL(string: "leaderkey://settings")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .settings)
  }

  func testAboutURL() {
    let url = URL(string: "leaderkey://about")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .about)
  }

  // MARK: - Navigation Tests

  func testNavigateWithKeys() {
    let url = URL(string: "leaderkey://navigate?keys=a,b,c")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .navigate(keys: ["a", "b", "c"], execute: true))
  }

  func testNavigateWithExecuteFalse() {
    let url = URL(string: "leaderkey://navigate?keys=a,b&execute=false")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .navigate(keys: ["a", "b"], execute: false))
  }

  func testNavigateWithExecuteTrue() {
    let url = URL(string: "leaderkey://navigate?keys=x,y&execute=true")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .navigate(keys: ["x", "y"], execute: true))
  }

  func testNavigateWithSingleKey() {
    let url = URL(string: "leaderkey://navigate?keys=z")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .navigate(keys: ["z"], execute: true))
  }

  func testNavigateWithoutKeys() {
    let url = URL(string: "leaderkey://navigate")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .show)
  }

  // MARK: - Named Action Tests

  func testRunWithName() {
    let url = URL(string: "leaderkey://run?name=Reply%20with%20thanks")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .run(name: "Reply with thanks"))
  }

  func testRunTrimsName() {
    let url = URL(string: "leaderkey://run?name=%20%20Reply%20%20")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .run(name: "Reply"))
  }

  func testRunWithoutNameFallsBackToShow() {
    let url = URL(string: "leaderkey://run")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .show)
  }

  func testRunWithEmptyNameFallsBackToShow() {
    let url = URL(string: "leaderkey://run?name=%20%20")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .show)
  }

  func testResolvesNestedUniqueLabel() {
    let root = makeRoot()
    let action = URLSchemeAction.run(name: "Nested").resolvedAction(
      in: root, automationEnabled: true)

    XCTAssertEqual(action?.key, "s")
  }

  func testRejectsDuplicateLabel() {
    let root = makeRoot()
    let action = URLSchemeAction.run(name: "Duplicate").resolvedAction(
      in: root, automationEnabled: true)

    XCTAssertNil(action)
  }

  func testRejectsMissingLabel() {
    let root = makeRoot()
    let action = URLSchemeAction.run(name: "Missing").resolvedAction(
      in: root, automationEnabled: true)

    XCTAssertNil(action)
  }

  func testRejectsGroupLabel() {
    let root = makeRoot()
    let action = URLSchemeAction.run(name: "Outer").resolvedAction(
      in: root, automationEnabled: true)

    XCTAssertNil(action)
  }

  func testAutomationGate() {
    let root = makeRoot()
    let action = URLSchemeAction.run(name: "Reply").resolvedAction(
      in: root, automationEnabled: false)

    XCTAssertNil(action)
  }

  private func makeRoot() -> Group {
    Group(
      key: nil,
      label: "Root",
      actions: [
        .action(Action(key: "r", type: .command, label: "Reply", value: "echo reply")),
        .group(
          Group(
            key: "o",
            label: "Outer",
            actions: [
              .action(
                Action(key: "s", type: .command, label: "Nested", value: "echo nested"))
            ])),
        .action(Action(key: "d", type: .command, label: "Duplicate", value: "echo one")),
        .action(Action(key: "e", type: .command, label: "Duplicate", value: "echo two")),
      ])
  }

  // MARK: - Invalid URL Tests

  func testInvalidScheme() {
    let url = URL(string: "invalid://settings")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .invalid)
  }

  func testUnknownHost() {
    let url = URL(string: "leaderkey://unknown")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .show)
  }
}
