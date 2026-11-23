import Foundation

enum CheatsheetSearch {
  static let maxResults = 100

  struct Result: Equatable, Identifiable {
    let item: ActionOrGroup
    let path: [String]

    var id: UUID { item.uiid }
  }

  static func results(
    in root: Group,
    query: String,
    limit: Int = maxResults
  ) -> [Result] {
    var rows: [Result] = []

    func walk(_ group: Group, ancestorKeys: [String], ancestorLabels: [String]) {
      for item in group.actions {
        if rows.count >= limit { return }

        let key = item.item.key ?? ""
        let path = key.isEmpty ? ancestorKeys : ancestorKeys + [key]

        switch item {
        case .action(let action):
          let fields: [String?] =
            [
              action.key,
              action.key.flatMap(KeyMaps.glyph),
              action.label,
              action.displayName,
              action.value,
            ] + ancestorLabels.map(Optional.some)
          if matches(fields, query: query) {
            rows.append(Result(item: item, path: path))
          }
        case .group(let child):
          let fields: [String?] =
            [
              child.key,
              child.key.flatMap(KeyMaps.glyph),
              child.label,
              child.displayName,
            ] + ancestorLabels.map(Optional.some)
          if matches(fields, query: query) {
            rows.append(Result(item: item, path: path))
          }

          let labels = ancestorLabels + [child.label, child.displayName].compactMap { $0 }
          walk(child, ancestorKeys: path, ancestorLabels: labels)
        }
      }
    }

    walk(root, ancestorKeys: [], ancestorLabels: [])
    return rows
  }

  private static func matches(_ fields: [String?], query: String) -> Bool {
    if query.isEmpty { return true }
    let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
    return fields.compactMap { $0 }.contains {
      $0.range(of: query, options: options, locale: .current) != nil
    }
  }
}
