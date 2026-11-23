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

  func testExactResultsComeBeforeFuzzyResults() {
    let root = Group(
      key: nil,
      actions: [
        .action(Action(key: "x", type: .command, label: "ghb", value: "")),
        .action(Action(key: "g", type: .command, label: "GitHub", value: "")),
      ])

    let results = CheatsheetSearch.results(in: root, query: "ghb")

    XCTAssertEqual(results.compactMap { $0.item.item.key }, ["x", "g"])
    XCTAssertFalse(results[1].highlights.isEmpty)
  }

  func testMultiTokenMatchesAcrossLabelAndGroupPath() {
    let root = Group(
      key: nil,
      actions: [
        .group(
          Group(
            key: "d",
            label: "Dev",
            actions: [
              .action(Action(key: "s", type: .command, label: "GitHub", value: ""))
            ]))
      ])

    let results = CheatsheetSearch.results(in: root, query: "gh dev")

    XCTAssertEqual(results.compactMap { $0.item.item.key }, ["s"])
  }

  func testFuzzyResultsCapAtFifty() {
    let actions = (0..<80).map { index in
      ActionOrGroup.action(
        Action(key: "k\(index)", type: .command, label: "G H B", value: ""))
    }
    let root = Group(key: nil, actions: actions)

    let results = CheatsheetSearch.results(in: root, query: "ghb")

    XCTAssertEqual(results.count, 50)
    XCTAssertEqual(results.first?.item.item.key, "k0")
  }

  func testEqualFuzzyScoresKeepConfigOrder() {
    let root = Group(
      key: nil,
      actions: [
        .action(Action(key: "a", type: .command, label: "GitHub", value: "")),
        .action(Action(key: "b", type: .command, label: "GitHub", value: "")),
      ])

    XCTAssertEqual(
      CheatsheetSearch.results(in: root, query: "ghb").compactMap { result in
        if case .action(let action) = result.item { return action.key }
        return nil
      },
      ["a", "b"])
  }

  func testOneCharacterQueryUsesSubstringOnly() {
    let root = Group(
      key: nil,
      actions: [
        .action(Action(key: "g", type: .command, label: "GitHub", value: "")),
        .action(Action(key: "z", type: .command, label: "Zebra", value: "")),
      ])

    XCTAssertEqual(CheatsheetSearch.results(in: root, query: "g").count, 1)
  }

  func testFuzzyDuplicateLabelsAppearOncePerItem() {
    let root = Group(
      key: nil,
      actions: [
        .action(Action(key: "a", type: .command, label: "Same", value: "")),
        .action(Action(key: "b", type: .command, label: "Same", value: "")),
      ])

    let results = CheatsheetSearch.results(in: root, query: "sme")

    XCTAssertEqual(results.compactMap { $0.item.item.key }, ["a", "b"])
  }

  func testTenThousandActionsFindFuzzyMatch() {
    var actions = (0..<10_000).map { index in
      ActionOrGroup.action(
        Action(key: "k\(index)", type: .command, label: "Filler", value: ""))
    }
    actions.append(
      .action(Action(key: "target", type: .command, label: "GitHub", value: "")))
    let root = Group(key: nil, actions: actions)

    let results = CheatsheetSearch.results(in: root, query: "ghb")

    guard case .action(let action)? = results.first?.item else {
      return XCTFail("Expected target action")
    }
    XCTAssertEqual(action.key, "target")
  }
}

final class FuzzyMatcherTests: XCTestCase {
  func testSubsequenceMatch() {
    let match = FuzzyMatcher.score("GitHub", query: "ghb")

    XCTAssertNotNil(match)
    XCTAssertEqual(
      match?.ranges ?? [],
      [0..<1, 3..<4, 5..<6])
  }

  func testNonSubsequenceReturnsNil() {
    XCTAssertNil(FuzzyMatcher.score("GitHub", query: "xyz"))
  }

  func testExactBeatsSubstringBeatsSubsequence() {
    let exact = FuzzyMatcher.score("github", query: "github")
    let substring = FuzzyMatcher.score("github-app", query: "github")
    let subsequence = FuzzyMatcher.score("g-i-t-h-u-b", query: "github")

    XCTAssertNotNil(exact)
    XCTAssertNotNil(substring)
    XCTAssertNotNil(subsequence)
    XCTAssertGreaterThan(exact!.score, substring!.score)
    XCTAssertGreaterThan(substring!.score, subsequence!.score)
  }

  func testConsecutiveMatchBeatsScatteredMatch() {
    let consecutive = FuzzyMatcher.score("ghost", query: "gh")
    let scattered = FuzzyMatcher.score("g---h", query: "gh")

    XCTAssertGreaterThan(consecutive!.score, scattered!.score)
  }

  func testCaseAndDiacriticFolding() {
    let text = "Café"
    let match = FuzzyMatcher.score(text, query: "CAFE")

    XCTAssertEqual(match?.score, FuzzyMatcher.score("cafe", query: "cafe")?.score)

    let ranges = FuzzyMatcher.originalRanges(in: text, normalizedRanges: match!.ranges)
    XCTAssertEqual(ranges.count, 1)
    XCTAssertEqual(String(text[ranges[0]]), text)
  }
}
