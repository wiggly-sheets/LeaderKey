import Foundation
import os

enum URLSchemeAction: Equatable {
  case settings
  case about
  case configReload
  case configReveal
  case activate
  case hide
  case reset
  case navigate(keys: [String], execute: Bool)
  case run(name: String)
  case show  // Fallback for unknown hosts
  case invalid  // Invalid scheme
}

class URLSchemeHandler {
  static func parse(_ url: URL) -> URLSchemeAction {
    guard url.scheme == "leaderkey" else {
      return .invalid
    }

    switch url.host {
    case "settings":
      return .settings
    case "about":
      return .about
    case "config-reload":
      return .configReload
    case "config-reveal":
      return .configReveal
    case "activate":
      return .activate
    case "hide":
      return .hide
    case "reset":
      return .reset
    case "navigate":
      guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
        let queryItems = components.queryItems,
        let keysParam = queryItems.first(where: { $0.name == "keys" })?.value
      else {
        return .show
      }
      let keys = keysParam.split(separator: ",").map(String.init)
      let execute = queryItems.first(where: { $0.name == "execute" })?.value != "false"
      return .navigate(keys: keys, execute: execute)
    case "run":
      guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
        let queryItems = components.queryItems,
        let name = queryItems.first(where: { $0.name == "name" })?.value
      else {
        return .show
      }
      let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
      return name.isEmpty ? .show : .run(name: name)
    default:
      return .show
    }
  }
}

extension URLSchemeAction {
  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "LeaderKey",
    category: "LeaderKey.URLScheme")

  func resolvedAction(in root: Group, automationEnabled: Bool) -> Action? {
    guard automationEnabled, case .run(let name) = self else { return nil }

    guard let action = root.firstAction(label: name) else {
      Self.logger.info("No action named \(name, privacy: .public)")
      return nil
    }

    guard !root.hasDuplicateActionLabel(name) else {
      Self.logger.info("Multiple actions named \(name, privacy: .public)")
      return nil
    }

    Self.logger.info("Resolved action named \(name, privacy: .public)")
    return action
  }
}
