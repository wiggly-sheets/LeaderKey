import Foundation

enum FuzzyMatcher {
  static func score(
    _ candidate: String,
    query: String
  ) -> (score: Int, ranges: [Range<Int>])? {
    score(
      normalizedCandidate: normalize(candidate),
      normalizedQuery: normalizeQuery(query))
  }

  static func normalizeQuery(_ query: String) -> String {
    let collapsed = query.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    return normalize(collapsed)
  }

  static func normalize(_ text: String) -> String {
    text.map { character in
      String(character)
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        .lowercased()
    }.joined()
  }

  static func score(
    normalizedCandidate: String,
    normalizedQuery: String
  ) -> (score: Int, ranges: [Range<Int>])? {
    let candidate = Array(normalizedCandidate)
    let query = Array(normalizedQuery)
    guard !query.isEmpty, query.count <= candidate.count else { return nil }

    if query.count == 1 {
      guard let index = candidate.firstIndex(of: query[0]) else { return nil }
      var score = 50 + positionalScore(candidate, positions: [index])
      if candidate.count == 1 { score += 100 }
      return (score, merge([index]))
    }

    if candidate == query {
      let positions = Array(0..<query.count)
      return (100 + positionalScore(candidate, positions: positions), merge(positions))
    }

    if let range = normalizedCandidate.range(of: normalizedQuery) {
      let start = normalizedCandidate.distance(
        from: normalizedCandidate.startIndex, to: range.lowerBound)
      let positions = Array(start..<(start + query.count))
      return (50 + positionalScore(candidate, positions: positions), merge(positions))
    }

    var positions: [Int] = []
    var queryIndex = 0
    for (index, character) in candidate.enumerated() {
      if character == query[queryIndex] {
        positions.append(index)
        queryIndex += 1
        if queryIndex == query.count { break }
      }
    }
    guard queryIndex == query.count else { return nil }

    return (positionalScore(candidate, positions: positions), merge(positions))
  }

  static func originalRanges(
    in text: String,
    normalizedRanges: [Range<Int>]
  ) -> [Range<String.Index>] {
    guard !normalizedRanges.isEmpty else { return [] }

    let original = Array(text)
    var indexMap: [Int] = []
    for (index, character) in original.enumerated() {
      let foldedCount = normalize(String(character)).count
      indexMap.append(contentsOf: repeatElement(index, count: foldedCount))
    }

    var ranges: [Range<String.Index>] = []
    for range in normalizedRanges {
      guard !range.isEmpty, range.lowerBound >= 0, range.upperBound <= indexMap.count
      else { continue }

      let startOffset = indexMap[range.lowerBound]
      let endOffset = indexMap[range.upperBound - 1] + 1
      let start = text.index(text.startIndex, offsetBy: startOffset)
      let end = text.index(text.startIndex, offsetBy: endOffset)
      ranges.append(start..<end)
    }

    ranges.sort { $0.lowerBound < $1.lowerBound }
    var merged: [Range<String.Index>] = []
    for range in ranges {
      if let last = merged.last, range.lowerBound <= last.upperBound {
        merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
      } else {
        merged.append(range)
      }
    }
    return merged
  }

  private static func positionalScore(_ candidate: [Character], positions: [Int]) -> Int {
    var score = 0
    for (matchIndex, position) in positions.enumerated() {
      if matchIndex > 0 {
        let gap = position - positions[matchIndex - 1] - 1
        if gap == 0 {
          score += 10
        } else {
          score -= min(gap, 20)
        }
      }
      if position == 0 || isSeparator(candidate[position - 1]) {
        score += 8
      }
    }
    if positions.first == 0 { score += 20 }
    return score
  }

  private static func isSeparator(_ character: Character) -> Bool {
    !character.isLetter && !character.isNumber
  }

  private static func merge(_ positions: [Int]) -> [Range<Int>] {
    var ranges: [Range<Int>] = []
    for position in positions {
      if let last = ranges.last, last.upperBound == position {
        ranges[ranges.count - 1] = last.lowerBound..<(position + 1)
      } else {
        ranges.append(position..<(position + 1))
      }
    }
    return ranges
  }
}
