import XCTest

@testable import Leader_Key

final class CheatsheetSearchTests: XCTestCase {
  func testEmptyQueryReturnsDepthFirstOrder() {
    let root = Group(
      key: nil,
      actions: [
        .action(Action(key: "a", type: .command, label: "Alpha", value: "")),
        .group(
          Group(
            key: "g",
            label: "Group",
            actions: [
              .action(Action(key: "b", type: .command, label: "Beta", value: "")),
              .action(Action(key: "c", type: .command, label: "Gamma", value: "")),
            ])),
        .action(Action(key: "d", type: .command, label: "Delta", value: "")),
      ])

    let results = CheatsheetSearch.results(in: root, query: "")

    XCTAssertEqual(results.compactMap { $0.item.item.key }, ["a", "g", "b", "c", "d"])
    XCTAssertEqual(results.first(where: { $0.item.item.key == "b" })?.path, ["g", "b"])
  }

  func testMatchesCaseAndDiacriticsInsensitively() {
    let root = Group(
      key: nil,
      actions: [
        .action(Action(key: "c", type: .command, label: "Café", value: ""))
      ])

    XCTAssertEqual(CheatsheetSearch.results(in: root, query: "CAFE").count, 1)
  }

  func testMatchesActionValue() {
    let root = Group(
      key: nil,
      actions: [
        .action(Action(key: "v", type: .command, label: "Other", value: "Needle"))
      ])

    XCTAssertEqual(CheatsheetSearch.results(in: root, query: "needle").count, 1)
  }

  func testGroupLabelIncludesDescendants() {
    let root = Group(
      key: nil,
      actions: [
        .group(
          Group(
            key: "o",
            label: "Outer",
            actions: [
              .action(Action(key: "s", type: .command, label: "Nested", value: ""))
            ]))
      ])

    let results = CheatsheetSearch.results(in: root, query: "outer")

    XCTAssertEqual(results.compactMap { $0.item.item.key }, ["o", "s"])
  }

  func testDuplicateLabelsAppearOncePerItem() {
    let root = Group(
      key: nil,
      actions: [
        .action(Action(key: "a", type: .command, label: "Same", value: "")),
        .action(Action(key: "b", type: .command, label: "Same", value: "")),
      ])

    XCTAssertEqual(CheatsheetSearch.results(in: root, query: "same").count, 2)
  }

  func testCapsResultsAtOneHundred() {
    let actions = (0..<120).map { index in
      ActionOrGroup.action(
        Action(key: "k\(index)", type: .command, label: "Item", value: ""))
    }
    let root = Group(key: nil, actions: actions)

    let results = CheatsheetSearch.results(in: root, query: "")

    XCTAssertEqual(results.count, 100)
    XCTAssertEqual(results.first?.item.item.key, "k0")
    XCTAssertEqual(results.last?.item.item.key, "k99")
  }
}
