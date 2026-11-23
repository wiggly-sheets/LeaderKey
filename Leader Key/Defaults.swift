import Cocoa
import Defaults
import SwiftUI

var defaultsSuite =
  ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
  ? UserDefaults(suiteName: UUID().uuidString)!
  : .standard

extension Defaults.Keys {
  static let configDir = Key<String>(
    "configDir", default: UserConfig.defaultDirectory(), suite: defaultsSuite)
  static let showMenuBarIcon = Key<Bool>(
    "showInMenubar", default: true, suite: defaultsSuite)
  static let forceEnglishKeyboardLayout = Key<Bool>(
    "forceEnglishKeyboardLayout", default: false, suite: defaultsSuite)
  static let modifierKeyConfiguration = Key<ModifierKeyConfig>(
    "modifierKeyConfiguration", default: .controlGroupOptionSticky, suite: defaultsSuite)
  static let theme = Key<Theme>(
    "theme", default: .mysteryBox, suite: defaultsSuite)
  static let backgroundStyle = Key<BackgroundStyle>(
    "backgroundStyle", default: .classic, suite: defaultsSuite)
  static let glassTintColor = Key<Color>(
    "glassTintColor", default: .clear, suite: defaultsSuite)
  static let urlSchemeAutomationEnabled = Key<Bool>(
    "urlSchemeAutomationEnabled", default: false, suite: defaultsSuite)

  static let autoOpenCheatsheet = Key<AutoOpenCheatsheetSetting>(
    "autoOpenCheatsheet",
    default: .delay, suite: defaultsSuite)
  static let cheatsheetDelayMS = Key<Int>(
    "cheatsheetDelayMS", default: 2000, suite: defaultsSuite)
  static let expandGroupsInCheatsheet = Key<Bool>(
    "expandGroupsInCheatsheet", default: false, suite: defaultsSuite)
  static let showAppIconsInCheatsheet = Key<Bool>(
    "showAppIconsInCheatsheet", default: true, suite: defaultsSuite)
  static let showDetailsInCheatsheet = Key<Bool>(
    "showDetailsInCheatsheet", default: true, suite: defaultsSuite)
  static let showFaviconsInCheatsheet = Key<Bool>(
    "showFaviconsInCheatsheet", default: true, suite: defaultsSuite)
  static let reactivateBehavior = Key<ReactivateBehavior>(
    "reactivateBehavior", default: .hide, suite: defaultsSuite)
  static let screen = Key<Screen>(
    "screen", default: .primary, suite: defaultsSuite)

  static let groupShortcuts = Key<Set<String>>(
    "groupShortcuts",
    default: Set(), suite: defaultsSuite)
  static let showHyperKeySymbol = Key<Bool>(
    "showHyperKeySymbol", default: false, suite: defaultsSuite)
}

enum BackgroundStyle: String, Defaults.Serializable, CaseIterable, Identifiable {
  case classic
  case glassRegular
  case glassClear

  var id: Self { self }

  var description: String {
    switch self {
    case .classic: return "Classic Blur"
    case .glassRegular: return "Liquid Glass"
    case .glassClear: return "Liquid Glass Clear"
    }
  }

  var isAvailable: Bool {
    if self == .classic { return true }
    if #available(macOS 26.0, *) { return true }
    return false
  }
}

enum AutoOpenCheatsheetSetting: String, Defaults.Serializable {
  case never
  case always
  case delay
}

enum ModifierKeyConfig: String, Codable, Defaults.Serializable, CaseIterable, Identifiable {
  case controlGroupOptionSticky
  case optionGroupControlSticky

  var id: Self { self }

  var description: String {
    switch self {
    case .controlGroupOptionSticky:
      return "⌃ Group sequences, ⌥ Sticky mode"
    case .optionGroupControlSticky:
      return "⌥ Group sequences, ⌃ Sticky mode"
    }
  }
}

enum ReactivateBehavior: String, Defaults.Serializable {
  case hide
  case reset
  case nothing
}

enum Screen: String, Defaults.Serializable {
  case primary
  case mouse
  case activeWindow
}
