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

extension GlassTint {
  var color: Color? {
    switch self {
    case .none: return nil
    case .blue: return .blue
    case .purple: return .purple
    case .green: return .green
    case .pink: return .pink
    case .orange: return .orange
    }
  }
}

/// Theme background that follows the user's background style setting.
struct ThemeBackground: View {
  @Default(.backgroundStyle) var style
  @Default(.glassTint) var tint
  var cornerRadius: CGFloat = 15

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    if #available(macOS 26.0, *), style != .classic {
      let glass = (style == .glassClear ? Glass.clear : Glass.regular).tint(tint.color)
      Color.clear.glassEffect(glass, in: shape)
    } else {
      VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
    }
  }
}
