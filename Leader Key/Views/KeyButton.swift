import AppKit
import Combine
import Defaults
import KeyboardShortcuts
import SwiftUI

typealias KeyChangedFn = ((_ before: String?, _ value: String?) -> Void)

struct KeyButton: View {
  @Binding var text: String
  let placeholder: String
  @State private var isListening = false
  @State private var oldValue = ""
  var validationError: ValidationErrorType? = nil
  var onKeyChanged: KeyChangedFn? = nil

  var body: some View {
    Button(action: {
      oldValue = text
      isListening = true
    }) {
      Text(text.isEmpty ? placeholder : (KeyMaps.glyph(for: text) ?? text))
        .frame(width: 32, height: 24)
        .background(
          RoundedRectangle(cornerRadius: 5)
            .fill(backgroundColor)
            .overlay(
              RoundedRectangle(cornerRadius: 5)
                .stroke(borderColor, lineWidth: 1)
            )
        )
        .foregroundColor(text.isEmpty ? .gray : .primary)
    }
    .buttonStyle(PlainButtonStyle())
    .background(
      KeyListenerView(
        isListening: $isListening, text: $text, oldValue: $oldValue, onKeyChanged: onKeyChanged))
  }

  private var backgroundColor: Color {
    if isListening {
      return Color.blue.opacity(0.3)
    } else if validationError != nil {
      return Color.red.opacity(0.1)
    } else {
      return Color(.controlBackgroundColor)
    }
  }

  private var borderColor: Color {
    if isListening {
      return Color.clear
    } else if validationError != nil {
      return Color.red
    } else {
      return Color.gray.opacity(0.5)
    }
  }
}

struct KeyListenerView: NSViewRepresentable {
  @Binding var isListening: Bool
  @Binding var text: String
  @Binding var oldValue: String
  var onKeyChanged: KeyChangedFn?

  func makeNSView(context: Context) -> NSView {
    let view = KeyListenerNSView()
    view.isListening = $isListening
    view.text = $text
    view.oldValue = $oldValue
    view.onKeyChanged = onKeyChanged
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    if let view = nsView as? KeyListenerNSView {
      view.isListening = $isListening
      view.text = $text
      view.oldValue = $oldValue
      view.onKeyChanged = onKeyChanged

      if isListening {
        DispatchQueue.main.async {
          view.window?.makeFirstResponder(view)
        }
      }
    }
  }

  class KeyListenerNSView: NSView {
    var isListening: Binding<Bool>?
    var text: Binding<String>?
    var oldValue: Binding<String>?
    var onKeyChanged: KeyChangedFn?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
      guard let isListening = isListening, let text = text, isListening.wrappedValue else {
        super.keyDown(with: event)
        return
      }

      let handled = KeyCapture.handle(
        event: event,
        onSet: { value in text.wrappedValue = value ?? "" },
        onCancel: { if let oldValue = self.oldValue { text.wrappedValue = oldValue.wrappedValue } },
        onClear: { text.wrappedValue = "" }
      )

      if handled {
        DispatchQueue.main.async {
          isListening.wrappedValue = false
          self.onKeyChanged?(self.oldValue?.wrappedValue, self.text?.wrappedValue)
        }
      } else {
        super.keyDown(with: event)
      }
    }

    override func resignFirstResponder() -> Bool {
      if let isListening = isListening, isListening.wrappedValue {
        DispatchQueue.main.async {
          isListening.wrappedValue = false
          self.onKeyChanged?(self.oldValue?.wrappedValue, self.text?.wrappedValue)
        }
      }
      return super.resignFirstResponder()
    }
  }
}

@MainActor
enum ShortcutDisplay {
  static func text(
    for shortcut: KeyboardShortcuts.Shortcut?,
    showHyperKeySymbol: Bool
  ) -> String {
    guard let shortcut else { return "" }

    let text = shortcut.description
    guard showHyperKeySymbol,
      shortcut.modifiers.contains([.control, .option, .shift, .command])
    else { return text }

    let key =
      text
      .replacingOccurrences(of: "⌃", with: "")
      .replacingOccurrences(of: "⌥", with: "")
      .replacingOccurrences(of: "⇧", with: "")
      .replacingOccurrences(of: "⌘", with: "")
    guard !key.isEmpty else { return text }

    let keyText = key.count == 1 ? key.lowercased() : key
    return "✦ + \(keyText)"
  }

  static func text(for shortcut: KeyboardShortcuts.Shortcut?) -> String {
    text(for: shortcut, showHyperKeySymbol: Defaults[.showHyperKeySymbol])
  }
}

final class ShortcutRecorderView: NSView {
  private let name: KeyboardShortcuts.Name
  private var recorder: KeyboardShortcuts.RecorderCocoa!
  private var displayCancellable: AnyCancellable?

  init(
    name: KeyboardShortcuts.Name,
    onChange: ((KeyboardShortcuts.Shortcut?) -> Void)? = nil
  ) {
    self.name = name
    super.init(frame: .zero)

    recorder = KeyboardShortcuts.RecorderCocoa(for: name) { [weak self] shortcut in
      onChange?(shortcut)
      self?.refreshDisplay()
    }
    recorder.translatesAutoresizingMaskIntoConstraints = false
    addSubview(recorder)
    NSLayoutConstraint.activate([
      recorder.leadingAnchor.constraint(equalTo: leadingAnchor),
      recorder.trailingAnchor.constraint(equalTo: trailingAnchor),
      recorder.topAnchor.constraint(equalTo: topAnchor),
      recorder.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])

    displayCancellable = Defaults.publisher(.showHyperKeySymbol).sink { [weak self] _ in
      self?.refreshDisplay()
    }
    refreshDisplay()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var intrinsicContentSize: NSSize {
    recorder.intrinsicContentSize
  }

  private func refreshDisplay() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.recorder.stringValue = ShortcutDisplay.text(
        for: KeyboardShortcuts.getShortcut(for: self.name))
    }
  }
}

struct ShortcutRecorder: NSViewRepresentable {
  let name: KeyboardShortcuts.Name
  var onChange: ((KeyboardShortcuts.Shortcut?) -> Void)? = nil

  func makeNSView(context: Context) -> ShortcutRecorderView {
    ShortcutRecorderView(name: name, onChange: onChange)
  }

  func updateNSView(_ nsView: ShortcutRecorderView, context: Context) {}
}

#Preview {
  struct Container: View {
    @State var text = "a"
    @StateObject var userConfig = UserConfig()

    var body: some View {
      VStack(spacing: 20) {
        KeyButton(
          text: $text,
          placeholder: "Key"
        )
        KeyButton(
          text: $text,
          placeholder: "Key",
          validationError: .duplicateKey
        )
        KeyButton(
          text: $text,
          placeholder: "Key",
          validationError: .emptyKey
        )
        KeyButton(
          text: $text,
          placeholder: "Key",
          validationError: .nonSingleCharacterKey
        )
        Text("Current value: '\(text)'")
      }
      .padding()
      .frame(width: 300)
      .environmentObject(userConfig)
    }
  }

  return Container()
}
