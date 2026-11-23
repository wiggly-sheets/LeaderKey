import Foundation

enum CheatsheetSearch {
  static let maxResults = 100
  static let maxFuzzyResults = 50

  struct Result: Equatable, Identifiable {
    let item: ActionOrGroup
    let path: [String]
    let highlights: [Range<Int>]

    init(item: ActionOrGroup, path: [String], highlights: [Range<Int>] = []) {
      self.item = item
      self.path = path
      self.highlights = highlights
    }

    var id: UUID { item.uiid }
  }

  static func results(
    in root: Group,
    query: String,
    limit: Int = maxResults
  ) -> [Result] {
    let normalizedQuery = FuzzyMatcher.normalizeQuery(query)
    let exact = exactResults(in: root, query: normalizedQuery, limit: limit)

    guard !normalizedQuery.isEmpty, normalizedQuery.count > 1, exact.count < limit
    else { return exact }

    let tokens = normalizedQuery.split(separator: " ").map(String.init)
    let fuzzy = fuzzyResults(
      in: root,
      tokens: tokens,
      limit: min(maxFuzzyResults, limit - exact.count),
      excluding: Set(exact.map(\.id)))
    return exact + fuzzy
  }

  private static func exactResults(
    in root: Group,
    query: String,
    limit: Int
  ) -> [Result] {
    let tokens = query.split(separator: " ").map(String.init)
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
            rows.append(
              Result(
                item: item, path: path,
                highlights: highlights(in: action.displayName, tokens: tokens)))
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
            rows.append(
              Result(
                item: item, path: path,
                highlights: highlights(in: child.displayName, tokens: tokens)))
          }

          let labels = ancestorLabels + [child.label, child.displayName].compactMap { $0 }
          walk(child, ancestorKeys: path, ancestorLabels: labels)
        }
      }
    }

    walk(root, ancestorKeys: [], ancestorLabels: [])
    return rows
  }

  private static func fuzzyResults(
    in root: Group,
    tokens: [String],
    limit: Int,
    excluding: Set<UUID>
  ) -> [Result] {
    var scored: [ScoredResult] = []
    var order = 0

    func walk(_ group: Group, ancestorKeys: [String], ancestorLabels: [String]) {
      for item in group.actions {
        let key = item.item.key ?? ""
        let path = key.isEmpty ? ancestorKeys : ancestorKeys + [key]
        let groupPath = ancestorLabels.joined(separator: " ")

        let fields: [(text: String, weight: Double)]
        switch item {
        case .action(let action):
          fields = [
            (action.label ?? "", 1.0),
            (action.key ?? "", 0.8),
            (action.displayName, 0.6),
            (action.value, 0.4),
            (groupPath, 0.3),
          ]
        case .group(let child):
          fields = [
            (child.label ?? "", 1.0),
            (child.key ?? "", 0.8),
            (child.displayName, 0.6),
            (groupPath, 0.3),
          ]
        }

        if let score = fuzzyScore(fields: fields, tokens: tokens), score > 0 {
          scored.append(
            ScoredResult(
              result: Result(item: item, path: path),
              score: score,
              order: order))
        }

        order += 1

        if case .group(let child) = item {
          let labels = ancestorLabels + [child.label, child.displayName].compactMap { $0 }
          walk(child, ancestorKeys: path, ancestorLabels: labels)
        }
      }
    }

    walk(root, ancestorKeys: [], ancestorLabels: [])

    let candidates = scored.filter {
      $0.score > 0 && !excluding.contains($0.result.id)
    }
    guard let best = candidates.map(\.score).max(), best > 0 else { return [] }
    let threshold = Double(best) * 0.25

    return
      candidates
      .filter { Double($0.score) >= threshold }
      .sorted {
        if $0.score != $1.score { return $0.score > $1.score }
        return $0.order < $1.order
      }
      .prefix(limit)
      .map { scored in
        Result(
          item: scored.result.item,
          path: scored.result.path,
          highlights: highlights(in: scored.result.item.item.displayName, tokens: tokens))
      }
  }

  private static func fuzzyScore(
    fields: [(text: String, weight: Double)],
    tokens: [String]
  ) -> Int? {
    let normalizedFields = fields.compactMap { field -> (text: String, weight: Double)? in
      guard !field.text.isEmpty else { return nil }
      return (FuzzyMatcher.normalize(field.text), field.weight)
    }

    var total = 0
    for token in tokens {
      let normalizedToken = FuzzyMatcher.normalizeQuery(token)
      var best = 0.0
      for field in normalizedFields {
        guard
          let match = FuzzyMatcher.score(
            normalizedCandidate: field.text, normalizedQuery: normalizedToken),
          match.score > 0
        else { continue }
        best = max(best, Double(match.score) * field.weight)
      }
      guard best > 0 else { return nil }
      total += Int(best.rounded())
    }
    return total
  }

  private static func matches(_ fields: [String?], query: String) -> Bool {
    if query.isEmpty { return true }
    let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
    return fields.compactMap { $0 }.contains {
      $0.range(of: query, options: options, locale: .current) != nil
    }
  }

  private static func highlights(in text: String, tokens: [String]) -> [Range<Int>] {
    var ranges = tokens.flatMap { token in
      FuzzyMatcher.score(text, query: token)?.ranges ?? []
    }
    ranges.sort { $0.lowerBound < $1.lowerBound }

    var merged: [Range<Int>] = []
    for range in ranges {
      if let last = merged.last, range.lowerBound <= last.upperBound {
        merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
      } else {
        merged.append(range)
      }
    }
    return merged
  }

  private struct ScoredResult {
    let result: Result
    let score: Int
    let order: Int
  }
}
