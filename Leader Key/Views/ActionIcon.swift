import Defaults
import Kingfisher
import SwiftUI

func actionIcon(item: ActionOrGroup, iconSize: NSSize, loadFavicons: Bool = true) -> some View {
  // Extract common properties
  let (iconPath, type, value): (String?, Type?, String?) =
    switch item {
    case .action(let action):
      (action.iconPath, action.type, action.value)
    case .group(let group):
      (group.iconPath, nil, nil)
    }

  // Handle custom icon path if present
  if let iconPath = iconPath, !iconPath.isEmpty {
    if iconPath.hasSuffix(".app") {
      return AnyView(AppIconImage(appPath: iconPath, size: iconSize))
    } else {
      return AnyView(
        Image(systemName: iconPath)
          .foregroundStyle(.secondary)
          .frame(width: iconSize.width, height: iconSize.height, alignment: .center)
      )
    }
  }

  // Handle type-specific icons
  if let type = type {
    switch type {
    case .application:
      return AnyView(AppIconImage(appPath: value ?? "", size: iconSize))
    case .url:
      if loadFavicons {
        return AnyView(FavIconImage(url: value ?? "", icon: "link"))
      } else {
        return AnyView(
          Image(systemName: "link")
            .foregroundStyle(.secondary)
            .frame(width: iconSize.width, height: iconSize.height, alignment: .center)
        )
      }
    case .command:
      return AnyView(
        Image(systemName: "terminal")
          .foregroundStyle(.secondary)
          .frame(width: iconSize.width, height: iconSize.height, alignment: .center))
    case .folder:
      return AnyView(
        Image(systemName: "folder")
          .foregroundStyle(.secondary)
          .frame(width: iconSize.width, height: iconSize.height, alignment: .center))
    default:
      return AnyView(
        Image(systemName: "questionmark")
          .foregroundStyle(.secondary)
          .frame(width: iconSize.width, height: iconSize.height, alignment: .center))
    }
  }

  // Default case for groups
  return AnyView(
    Image(systemName: "folder")
      .foregroundStyle(.secondary)
      .frame(width: iconSize.width, height: iconSize.height, alignment: .center)
  )
}

struct AppIconImage: View {
  let appPath: String
  let size: NSSize
  let defaultSystemName: String = "questionmark.circle"

  init(appPath: String, size: NSSize = NSSize(width: 24, height: 24)) {
    self.appPath = appPath
    self.size = size
  }

  var body: some View {
    let image =
      if let icon = getAppIcon(path: appPath) {
        Image(nsImage: icon)
      } else {
        Image(systemName: defaultSystemName)
      }
    image.resizable()
      .scaledToFit()
      .frame(width: size.width, height: size.height)
  }

  private func getAppIcon(path: String) -> NSImage? {
    guard FileManager.default.fileExists(atPath: path) else {
      return nil
    }

    let icon = NSWorkspace.shared.icon(forFile: path)
    let resizedIcon = NSImage(size: size, flipped: false) { rect in
      let iconRect = NSRect(origin: .zero, size: icon.size)
      icon.draw(in: rect, from: iconRect, operation: .sourceOver, fraction: 1)
      return true
    }
    return resizedIcon
  }
}

struct FavIconImage: View {
  private enum Source {
    case duckDuckGo
    case google
  }

  let sourceURL: String
  let host: String
  let icon: String
  let size: NSSize
  @State private var source: Source = .duckDuckGo

  init(url: String, icon: String, size: NSSize = NSSize(width: 24, height: 24)) {
    // Send only the host to icon providers, never the full URL with path or query.
    self.sourceURL = url
    let components = URLComponents(string: url)
    let scheme = components?.scheme?.lowercased()
    let host = components?.host ?? ""
    self.host = (scheme == "http" || scheme == "https") ? host : ""
    self.size = size
    self.icon = icon
  }

  private var faviconURL: URL? {
    guard !host.isEmpty else { return nil }
    switch source {
    case .duckDuckGo:
      return URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")
    case .google:
      return URL(string: "https://www.google.com/s2/favicons?sz=128&domain=\(host)")
    }
  }

  var fallback: some View {
    return Image(systemName: icon).foregroundStyle(.secondary)
      .frame(width: size.width, height: size.height, alignment: .center)
  }

  var body: some View {
    SwiftUI.Group {
      if let faviconURL {
        KFImage.url(faviconURL).placeholder({
          fallback
        }).onFailure { (_: KingfisherError) in
          source = .google
        }.resizable()
          .padding(4)
          .frame(width: size.width, height: size.height, alignment: .center)
      } else {
        fallback
      }
    }
    .onChange(of: sourceURL) { _ in
      source = .duckDuckGo
    }
  }
}

struct AppImagePreview: PreviewProvider {
  static var previews: some View {
    let appPaths = ["/Applications/Xcode.app", "/Applications/Safari.app", "/invalid/path"]
    VStack {
      ForEach(appPaths, id: \.self) { path in
        AppIconImage(appPath: path)
      }
    }
    .padding()
  }
}
