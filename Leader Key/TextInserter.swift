import AppKit
import ApplicationServices
import Carbon

enum TextInserter {
  enum Segment: Equatable {
    case text(String)
    case newline
    case tab
  }

  private static var promptedForAccessibility = false

  static func segments(for text: String) -> [Segment] {
    let units = Array(text.utf16)
    var result: [Segment] = []
    var buffer: [UniChar] = []

    func flush() {
      guard !buffer.isEmpty else { return }
      result.append(.text(String(decoding: buffer, as: UTF16.self)))
      buffer.removeAll(keepingCapacity: true)
    }

    var index = 0
    while index < units.count {
      let unit = units[index]

      if unit == 0x0A {
        flush()
        result.append(.newline)
        index += 1
        continue
      }
      if unit == 0x09 {
        flush()
        result.append(.tab)
        index += 1
        continue
      }
      if unit < 0x20 || unit == 0x7F {
        index += 1
        continue
      }

      let isHighSurrogate = unit >= 0xD800 && unit <= 0xDBFF
      let hasLowSurrogate =
        index + 1 < units.count && units[index + 1] >= 0xDC00 && units[index + 1] <= 0xDFFF
      let width = isHighSurrogate && hasLowSurrogate ? 2 : 1

      if buffer.count + width > 20 {
        flush()
      }

      buffer.append(unit)
      if width == 2 {
        buffer.append(units[index + 1])
      }
      index += width

      if buffer.count == 20 {
        flush()
      }
    }

    flush()
    return result
  }

  static func insert(_ text: String) {
    guard !text.isEmpty else { return }

    guard !IsSecureEventInputEnabled() else {
      showAlert(
        title: "Secure input is active",
        message: "Leader Key cannot insert text while secure input is enabled.")
      return
    }

    guard AXIsProcessTrusted() else {
      if !promptedForAccessibility {
        promptedForAccessibility = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
      }
      showAlert(
        title: "Accessibility permission required",
        message:
          "Enable Leader Key in System Settings > Privacy & Security > Accessibility to insert text snippets."
      )
      return
    }

    DispatchQueue.global(qos: .userInteractive).async {
      post(segments(for: text))
    }
  }

  private static func post(_ segments: [Segment]) {
    let source = CGEventSource(stateID: .hidSystemState)

    for segment in segments {
      switch segment {
      case .text(let text):
        postUnicode(text, source: source)
      case .newline:
        postKey(CGKeyCode(kVK_Return), source: source)
      case .tab:
        postKey(CGKeyCode(kVK_Tab), source: source)
      }
    }
  }

  private static func postUnicode(_ text: String, source: CGEventSource?) {
    let units = Array(text.utf16)
    guard
      let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
      let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
    else { return }

    units.withUnsafeBufferPointer { buffer in
      down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: buffer.baseAddress)
      up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: buffer.baseAddress)
    }
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
  }

  private static func postKey(_ keyCode: CGKeyCode, source: CGEventSource?) {
    CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)?
      .post(tap: .cghidEventTap)
    CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)?
      .post(tap: .cghidEventTap)
  }

  private static func showAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }
}
