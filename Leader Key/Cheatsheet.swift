import Combine
import Defaults
import Kingfisher
import SwiftUI

enum Cheatsheet {
  private static let iconSize = NSSize(width: 24, height: 24)

  struct KeyBadge: SwiftUI.View {
    let key: String

    var body: some SwiftUI.View {
      Text(KeyMaps.glyph(for: key) ?? key)
        .font(.system(.body, design: .rounded))
        .multilineTextAlignment(.center)
        .fontWeight(.bold)
        .padding(.vertical, 4)
        .frame(width: 24)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 5.0, style: .continuous))
    }
  }

  struct ActionRow: SwiftUI.View {
    let action: Action
    let indent: Int
    @Default(.showDetailsInCheatsheet) var showDetails
    @Default(.showAppIconsInCheatsheet) var showIcons

    var body: some SwiftUI.View {
      HStack {
        HStack {
          ForEach(0..<indent, id: \.self) { _ in
            Text("  ")
          }
          KeyBadge(key: action.key ?? "●")

          if showIcons {
            actionIcon(item: ActionOrGroup.action(action), iconSize: iconSize)
          }

          Text(action.displayName)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        Spacer()
        if showDetails {
          Text(action.value)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      }
    }
  }

  struct GroupRow: SwiftUI.View {
    @Default(.expandGroupsInCheatsheet) var expand
    @Default(.showDetailsInCheatsheet) var showDetails
    @Default(.showAppIconsInCheatsheet) var showIcons

    let group: Group
    let indent: Int

    var body: some SwiftUI.View {
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          ForEach(0..<indent, id: \.self) { _ in
            Text("  ")
          }
          KeyBadge(key: group.key ?? "")

          if showIcons {
            actionIcon(item: ActionOrGroup.group(group), iconSize: iconSize)
          }

          Image(systemName: "chevron.right")
            .foregroundStyle(.secondary)

          Text(group.displayName)

          Spacer()
          if showDetails {
            Text("\(group.actions.count.description) item(s)")
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }
        }
        if expand {
          ForEach(Array(group.actions.enumerated()), id: \.offset) { _, item in
            switch item {
            case .action(let action):
              Cheatsheet.ActionRow(action: action, indent: indent + 1)
            case .group(let group):
              Cheatsheet.GroupRow(group: group, indent: indent + 1)
            }
          }
        }
      }
    }
  }

  struct SearchResultRow: SwiftUI.View {
    let result: CheatsheetSearch.Result
    let isSelected: Bool
    @Default(.showDetailsInCheatsheet) var showDetails
    @Default(.showAppIconsInCheatsheet) var showIcons

    var body: some SwiftUI.View {
      HStack {
        KeyBadge(key: result.item.item.key ?? "●")

        if showIcons {
          actionIcon(item: result.item, iconSize: iconSize)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(highlightedName)
            .lineLimit(1)
            .truncationMode(.middle)

          if !result.path.isEmpty {
            Text(result.path.joined(separator: " › "))
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }
        }

        Spacer()

        if showDetails, case .action(let action) = result.item {
          Text(action.value)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      }
      .padding(.vertical, 3)
      .padding(.horizontal, 4)
      .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var highlightedName: AttributedString {
      let text = result.item.item.displayName
      let ranges = FuzzyMatcher.originalRanges(
        in: text, normalizedRanges: result.highlights)
      guard !ranges.isEmpty else { return AttributedString(text) }

      var highlighted = AttributedString()
      var cursor = text.startIndex
      for range in ranges {
        if cursor < range.lowerBound {
          highlighted.append(AttributedString(String(text[cursor..<range.lowerBound])))
        }
        var part = AttributedString(String(text[range]))
        part.foregroundColor = .accentColor
        part.underlineStyle = .single
        highlighted.append(part)
        cursor = range.upperBound
      }
      if cursor < text.endIndex {
        highlighted.append(AttributedString(String(text[cursor...])))
      }
      return highlighted
    }
  }

  struct CheatsheetView: SwiftUI.View {
    @EnvironmentObject var userState: UserState
    @State private var contentHeight: CGFloat = 0
    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var isSearchActive = false
    @State private var selectedIndex = 0
    @State private var window: NSWindow?
    @FocusState private var searchFocused: Bool

    var maxHeight: CGFloat {
      if let screen = NSScreen.main {
        return screen.visibleFrame.height - 40  // Leave some margin
      }
      return 640
    }

    // Constrain to edge of screen
    static var preferredWidth: CGFloat {
      if let screen = NSScreen.main {
        let screenHalf = screen.visibleFrame.width / 2
        let desiredWidth: CGFloat = 580
        let margin: CGFloat = 20
        return desiredWidth > screenHalf ? screenHalf - margin : desiredWidth
      }
      return 580
    }

    var actions: [ActionOrGroup] {
      (userState.currentGroup != nil)
        ? userState.currentGroup!.actions : userState.userConfig.root.actions
    }

    var searchResults: [CheatsheetSearch.Result] {
      CheatsheetSearch.results(in: userState.userConfig.root, query: debouncedQuery)
    }

    var body: some SwiftUI.View {
      ScrollView {
        SwiftUI.VStack(alignment: .leading, spacing: 4) {
          searchHeader

          if query.isEmpty {
            if let group = userState.currentGroup {
              HStack {
                KeyBadge(key: group.key ?? "•")
                Text(group.key == nil ? "Leader Key" : group.displayName)
                  .foregroundStyle(.secondary)
              }
              .padding(.bottom, 8)
              Divider()
                .padding(.bottom, 8)
            }

            ForEach(Array(actions.enumerated()), id: \.offset) { _, item in
              switch item {
              case .action(let action):
                Cheatsheet.ActionRow(action: action, indent: 0)
              case .group(let group):
                Cheatsheet.GroupRow(group: group, indent: 0)
              }
            }
          } else if searchResults.isEmpty {
            Text("No matches")
              .foregroundStyle(.secondary)
              .padding(.vertical, 8)
          } else {
            ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, result in
              Cheatsheet.SearchResultRow(
                result: result,
                isSelected: index == selectedIndex
              )
              .contentShape(Rectangle())
              .onTapGesture {
                selectedIndex = index
                activate(result)
              }
            }
          }
        }
        .padding()
        .overlay(
          GeometryReader { geo in
            Color.clear.preference(
              key: HeightPreferenceKey.self,
              value: geo.size.height
            )
          }
        )
      }
      .frame(width: Cheatsheet.CheatsheetView.preferredWidth)
      .frame(height: min(contentHeight, maxHeight))
      .background(
        ThemeBackground()
      )
      .background(
        WindowAccessor { newWindow in
          if window !== newWindow { window = newWindow }
        }
      )
      .onPreferenceChange(HeightPreferenceKey.self) { height in
        self.contentHeight = height
      }
      .onReceive(NotificationCenter.default.publisher(for: .lkCheatsheetSearch)) { _ in
        beginSearch()
      }
      .onChange(of: query) { value in
        selectedIndex = 0
        if value.count <= 1 || debouncedQuery.isEmpty {
          debouncedQuery = value
        }
      }
      .task(id: query) {
        guard query.count > 1 else { return }
        try? await Task.sleep(nanoseconds: 100_000_000)
        guard !Task.isCancelled else { return }
        debouncedQuery = query
      }
      .onChange(of: searchResults.count) { count in
        selectedIndex = min(selectedIndex, max(0, count - 1))
      }
    }

    private var searchHeader: some SwiftUI.View {
      HStack(spacing: 6) {
        Button {
          beginSearch()
        } label: {
          Image(systemName: "magnifyingglass")
        }
        .buttonStyle(.plain)
        .help("Search cheatsheet (⌘F)")

        if isSearchActive {
          TextField("Search", text: $query)
            .textFieldStyle(.plain)
            .focused($searchFocused)
            .onSubmit { activateSelected() }
            .onMoveCommand { direction in
              switch direction {
              case .up:
                selectedIndex = max(0, selectedIndex - 1)
              case .down:
                selectedIndex = min(max(0, searchResults.count - 1), selectedIndex + 1)
              default:
                break
              }
            }
            .onExitCommand { handleEscape() }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 5))

          if !query.isEmpty {
            Button {
              query = ""
            } label: {
              Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
          }
        }

        Spacer()
      }
      .padding(.bottom, 6)
    }

    private func beginSearch() {
      isSearchActive = true
      window?.makeKey()
      DispatchQueue.main.async {
        searchFocused = true
      }
    }

    private func endSearch() {
      isSearchActive = false
      query = ""
      searchFocused = false
      selectedIndex = 0
      NotificationCenter.default.post(name: .lkCheatsheetEndSearch, object: nil)
    }

    private func handleEscape() {
      if !query.isEmpty {
        query = ""
        return
      }
      endSearch()
    }

    private func activateSelected() {
      let results = CheatsheetSearch.results(in: userState.userConfig.root, query: query)
      guard !query.isEmpty, results.indices.contains(selectedIndex) else { return }
      activate(results[selectedIndex])
    }

    private func activate(_ result: CheatsheetSearch.Result) {
      isSearchActive = false
      query = ""
      searchFocused = false

      switch result.item {
      case .action(let action):
        NotificationCenter.default.post(name: .lkCheatsheetRunAction, object: action)
      case .group(let group):
        NotificationCenter.default.post(name: .lkCheatsheetNavigate, object: group)
      }
    }

    private struct WindowAccessor: NSViewRepresentable {
      let onWindow: (NSWindow?) -> Void

      func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onWindow(view.window) }
        return view
      }

      func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onWindow(nsView.window) }
      }
    }
  }

  struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
      value = nextValue()
    }
  }

  static func createWindow(for userState: UserState) -> NSWindow {
    let view = CheatsheetView().environmentObject(userState)
    let controller = NSHostingController(rootView: view)
    let cheatsheet = PanelWindow(
      contentRect: NSRect(x: 0, y: 0, width: 580, height: 640)
    )
    cheatsheet.contentViewController = controller
    return cheatsheet
  }
}

extension Notification.Name {
  static let lkCheatsheetSearch = Notification.Name("LKCheatsheetSearch")
  static let lkCheatsheetEndSearch = Notification.Name("LKCheatsheetEndSearch")
  static let lkCheatsheetRunAction = Notification.Name("LKCheatsheetRunAction")
  static let lkCheatsheetNavigate = Notification.Name("LKCheatsheetNavigate")
}

struct CheatsheetView_Previews: PreviewProvider {
  static var previews: some View {
    Cheatsheet.CheatsheetView()
      .environmentObject(UserState(userConfig: UserConfig()))
  }
}
