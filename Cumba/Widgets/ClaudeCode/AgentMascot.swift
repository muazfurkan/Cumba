import SwiftUI

/// The mark for an AI agent session: Claude Code's pixel mascot, as it appears in Claude
/// Code's own terminal, or a terminal for Codex. Drawn here, in the agent's color.
struct AgentGlyph: View {
  var agent = Agent.claude
  /// The mark's height.
  var size: CGFloat = 16
  /// The agent's color unless set.
  var color: Color?

  var body: some View {
    Group {
      switch agent {
      case .claude:
        ClaudeMascot()
          .fill(color ?? agent.color)
          .frame(width: size * ClaudeMascot.aspectRatio, height: size)
      case .codex:
        Image(systemName: "apple.terminal.fill")
          .font(.system(size: size * 0.9, weight: .semibold))
          .foregroundStyle(color ?? agent.color)
      }
    }
    .accessibilityHidden(true)
  }
}

/// Claude Code's mascot as a pixel grid: a body with two eyes, arms and four legs.
struct ClaudeMascot: Shape {
  /// Filled columns of each row, left to right, on a 16 by 6 grid.
  private static let rows: [[ClosedRange<Int>]] = [
    [2...13],
    [2...3, 5...10, 12...13],
    [0...15],
    [2...13],
    [3...3, 5...5, 10...10, 12...12],
    [3...3, 5...5, 10...10, 12...12],
  ]
  private static let columns = 16
  /// Pixels are a little taller than wide, like the terminal's block characters.
  static let aspectRatio: CGFloat = 16 / 9

  func path(in rect: CGRect) -> Path {
    let width = rect.width / CGFloat(Self.columns)
    let height = rect.height / CGFloat(Self.rows.count)
    var path = Path()
    for (row, runs) in Self.rows.enumerated() {
      for run in runs {
        // A hair of overlap keeps antialiasing from showing seams between rows.
        path.addRect(
          CGRect(
            x: rect.minX + CGFloat(run.lowerBound) * width,
            y: rect.minY + CGFloat(row) * height,
            width: CGFloat(run.count) * width,
            height: height + 0.3))
      }
    }
    return path
  }
}

/// A notification's icon: the agent's mark on a tile in its color, with a badge that says
/// what the notification is about.
struct AgentNoticeIcon: View {
  let agent: Agent
  let notice: AgentNotice

  var body: some View {
    RoundedRectangle(cornerRadius: 10, style: .continuous)
      .fill(
        LinearGradient(
          colors: [agent.color.mix(with: .white, by: 0.1), agent.color.mix(with: .black, by: 0.2)],
          startPoint: .top, endPoint: .bottom)
      )
      .overlay { AgentGlyph(agent: agent, size: 14, color: .white) }
      .overlay(alignment: .bottomTrailing) {
        Image(systemName: notice.symbol)
          .font(.system(size: 9, weight: .heavy))
          .foregroundStyle(.black.opacity(0.8))
          .frame(width: 18, height: 18)
          .background(notice.color, in: Circle())
          .overlay(Circle().stroke(.black, lineWidth: 2))
          .offset(x: 5, y: 5)
      }
      .accessibilityHidden(true)
  }
}

/// What the agent wants, beside the closed notch once its notification folds.
struct AgentNoticeBadge: View {
  let agent: Agent
  let notice: AgentNotice
  @Environment(\.peekHeight) private var height

  var body: some View {
    Image(systemName: notice.peekSymbol)
      .font(.system(size: max(13, height * 0.46), weight: .semibold))
      // A dark mark on a solid shape in the notice's color, like the notification's badge.
      .symbolRenderingMode(.palette)
      .foregroundStyle(.black.opacity(0.8), notice.color)
      .accessibilityLabel(Text(verbatim: notice.title(for: agent)))
  }
}
