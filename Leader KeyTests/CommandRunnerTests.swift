import XCTest

@testable import Leader_Key

final class CommandRunnerTests: XCTestCase {
  func testPrepareWithoutPlaceholderIsUnchanged() {
    XCTAssertEqual(
      CommandRunner.prepare(command: "echo hello", clipboard: "ignored"),
      "echo hello")
  }

  func testPrepareQuotesClipboardAsOneShellWord() {
    let clipboard = "a b 'c' \"d\" `e` $HOME\nf"

    XCTAssertEqual(
      CommandRunner.prepare(command: "printf '%s' {{clipboard}}", clipboard: clipboard),
      "printf '%s' 'a b '\\''c'\\'' \"d\" `e` $HOME\nf'")
  }

  func testPrepareReplacesEveryOccurrence() {
    XCTAssertEqual(
      CommandRunner.prepare(command: "{{clipboard}} {{clipboard}}", clipboard: "x"),
      "'x' 'x'")
  }

  func testPrepareLeavesEscapedPlaceholderLiteral() {
    XCTAssertEqual(
      CommandRunner.prepare(command: "echo \\{{clipboard}}", clipboard: "x"),
      "echo {{clipboard}}")
  }

  func testPrepareLeavesUnknownPlaceholdersUntouched() {
    XCTAssertEqual(
      CommandRunner.prepare(command: "echo {{other}} {{clipboard}}", clipboard: "x"),
      "echo {{other}} 'x'")
  }

  func testPrepareUsesEmptyStringForEmptyClipboard() {
    XCTAssertEqual(
      CommandRunner.prepare(command: "echo {{clipboard}}", clipboard: ""),
      "echo ''")
  }

  func testPrepareStripsNullCharacters() {
    XCTAssertEqual(
      CommandRunner.prepare(command: "{{clipboard}}", clipboard: "a\0b"),
      "'ab'")
  }

  func testPrepareRejectsClipboardOverOneMiB() {
    let clipboard = String(repeating: "a", count: CommandRunner.clipboardLimit + 1)

    XCTAssertNil(CommandRunner.prepare(command: "echo {{clipboard}}", clipboard: clipboard))
  }

  func testPrepareIgnoresOversizedClipboardWithoutPlaceholder() {
    let clipboard = String(repeating: "a", count: CommandRunner.clipboardLimit + 1)

    XCTAssertEqual(
      CommandRunner.prepare(command: "echo hello", clipboard: clipboard),
      "echo hello")
  }
}
