import Foundation

/// One line of a line-based diff, for showing settings changes before writing them.
struct DiffLine: Identifiable, Equatable, Sendable {
  enum Kind: Equatable, Sendable {
    case context
    case added
    case removed
  }

  let id: Int
  let kind: Kind
  let text: String

  /// Changed lines with `context` unchanged lines around each change. Long unchanged runs
  /// collapse into a single "…" line.
  static func lines(from old: String, to new: String, context: Int = 2) -> [DiffLine] {
    let oldLines = old.isEmpty ? [] : old.components(separatedBy: "\n")
    let newLines = new.isEmpty ? [] : new.components(separatedBy: "\n")
    let difference = newLines.difference(from: oldLines)
    var removed = Set<Int>()
    var inserted = Set<Int>()
    for change in difference {
      switch change {
      case .remove(let offset, _, _): removed.insert(offset)
      case .insert(let offset, _, _): inserted.insert(offset)
      }
    }

    var merged: [(Kind, String)] = []
    var oldIndex = 0
    var newIndex = 0
    while oldIndex < oldLines.count || newIndex < newLines.count {
      if oldIndex < oldLines.count, removed.contains(oldIndex) {
        merged.append((.removed, oldLines[oldIndex]))
        oldIndex += 1
      } else if newIndex < newLines.count, inserted.contains(newIndex) {
        merged.append((.added, newLines[newIndex]))
        newIndex += 1
      } else if newIndex < newLines.count {
        merged.append((.context, newLines[newIndex]))
        oldIndex += 1
        newIndex += 1
      } else {
        oldIndex += 1
      }
    }

    let changed = merged.indices.filter { merged[$0].0 != .context }
    var result: [DiffLine] = []
    var lastShown = -1
    for index in merged.indices {
      let nearChange = changed.contains { abs($0 - index) <= context }
      guard nearChange else { continue }
      if lastShown >= 0 && index > lastShown + 1 {
        result.append(DiffLine(id: result.count, kind: .context, text: "…"))
      }
      result.append(DiffLine(id: result.count, kind: merged[index].0, text: merged[index].1))
      lastShown = index
    }
    return result
  }
}
