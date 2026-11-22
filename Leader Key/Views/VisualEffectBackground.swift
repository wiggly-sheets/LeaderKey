import Defaults
import SwiftUI

struct VisualEffectView: NSViewRepresentable {
  var material: NSVisualEffectView.Material
  var blendingMode: NSVisualEffectView.BlendingMode

  func makeNSView(context _: Context) -> NSVisualEffectView {
    let visualEffectView = NSVisualEffectView()
    visualEffectView.material = material
    visualEffectView.blendingMode = blendingMode
    visualEffectView.state = .active
    visualEffectView.wantsLayer = true
    visualEffectView.layer?.cornerRadius = 15
    return visualEffectView
  }

  func updateNSView(_ visualEffectView: NSVisualEffectView, context _: Context) {
    visualEffectView.material = material
    visualEffectView.blendingMode = blendingMode
  }
}

/// Theme background that follows the user's background style setting.
struct ThemeBackground: View {
  @Default(.backgroundStyle) var style
  var cornerRadius: CGFloat = 15

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    if #available(macOS 26.0, *), style != .classic {
      Color.clear
        .glassEffect(style == .glassClear ? .clear : .regular, in: shape)
    } else {
      VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
    }
  }
}
