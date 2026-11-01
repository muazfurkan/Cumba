import SwiftUI

/// A turning ring beside the closed notch while an agent works. Still with Reduce Motion.
struct AgentSpinner: View {
  var agent = Agent.claude
  @Environment(\.peekHeight) private var height
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var turned = false

  var body: some View {
    let size = max(14, height * 0.45)
    // Inset by half the line so the stroke stays inside the frame.
    Circle()
      .inset(by: 1.5)
      .trim(from: 0, to: 0.72)
      .stroke(agent.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
      .background(Circle().inset(by: 1.5).stroke(agent.color.opacity(0.22), lineWidth: 3))
      .frame(width: size, height: size)
      .rotationEffect(.degrees(turned ? 360 : 0))
      .onAppear {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { turned = true }
      }
      .accessibilityLabel(Text("Working"))
  }
}

/// The busiest session on two pages: Progress (what it's doing and its last answer) and
/// Usage (how full its context window is). Alone in its tab the answer sits beside the
/// status in a bubble. With several sessions, "+N" steps through them.
struct AgentPanel: View {
  let service: ClaudeCodeService
  @State private var page = Page.progress
  /// A session picked with "+N"; nil follows the busiest one.
  @State private var pickedSessionID: String?
  @Environment(\.showsDetailedWidget) private var isDetailed

  enum Page {
    case progress
    case usage
  }

  private var session: ClaudeCodeService.Session? {
    service.sessions.first { $0.id == pickedSessionID }
      ?? service.sessions.first(where: \.isActive) ?? service.sessions.first
  }

  /// Shows the next session in the list, round to the first.
  private func showNextSession() {
    let sessions = service.sessions
    guard sessions.count > 1 else { return }
    let index = sessions.firstIndex { $0.id == session?.id } ?? 0
    withAnimation(.easeOut(duration: 0.2)) {
      pickedSessionID = sessions[(index + 1) % sessions.count].id
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Label {
          page == .progress ? Text("Progress") : Text("Usage")
        } icon: {
          Image(systemName: page == .progress ? "list.bullet" : "gauge.with.dots.needle.33percent")
        }
        .panelFont(.caption)
        .foregroundStyle(.secondary)
        Spacer()
        let others = service.sessions.count - 1
        if others > 0 {
          Button(action: showNextSession) {
            Text("+\(others)", comment: "More AI agent sessions are running")
              .panelFont(.caption2, weight: .semibold)
              .foregroundStyle(.secondary)
          }
          .buttonStyle(PanelButtonStyle(size: 24))
          .help(Text("Show the next session"))
        }
        pageButton(.progress, symbol: "list.bullet", label: Text("Progress"))
        pageButton(.usage, symbol: "gauge.with.dots.needle.33percent", label: Text("Usage"))
      }
      if let session {
        switch page {
        case .progress: progress(session)
        case .usage: usage(session)
        }
      }
    }
  }

  private func pageButton(_ target: Page, symbol: String, label: Text) -> some View {
    Button {
      withAnimation(.easeOut(duration: 0.2)) { page = target }
    } label: {
      Image(systemName: symbol)
    }
    .buttonStyle(PanelButtonStyle(size: 24, isSelected: page == target))
    .help(label)
    .accessibilityLabel(label)
  }

  private func progress(_ session: ClaudeCodeService.Session) -> some View {
    HStack(alignment: .top, spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 6) {
          AgentGlyph(agent: session.agent, size: 16)
          Text(verbatim: session.agent.name)
            .panelFont(.headline)
          if let title = session.title {
            Text(verbatim: "•").foregroundStyle(session.agent.color)
            Text(title)
              .panelFont(.callout, weight: .semibold)
              .foregroundStyle(session.agent.color)
              .lineLimit(1)
          }
        }
        Label {
          Text(Self.status(of: session))
            .panelFont(.callout, weight: .medium)
            .lineLimit(1)
        } icon: {
          Image(systemName: Self.symbol(of: session))
            .foregroundStyle(session.agent.color)
        }
        Text(session.project)
          .panelFont(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
        if !isDetailed, let detail = session.detail {
          bubble(detail)
        }
      }
      if isDetailed, let detail = session.detail {
        Spacer(minLength: 0)
        bubble(detail)
          .frame(maxWidth: 260, alignment: .trailing)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// The answer as tall as the panel allows; the tab grows for it up to a limit, and
  /// whatever doesn't fit then is cut off at the end.
  private func bubble(_ text: String) -> some View {
    Text(text)
      .panelFont(.callout)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.1)))
  }

  private func usage(_ session: ClaudeCodeService.Session) -> some View {
    HStack(spacing: 16) {
      ZStack {
        Circle().stroke(session.agent.color.opacity(0.2), lineWidth: 7)
        Circle()
          .trim(from: 0, to: session.contextFraction ?? 0)
          .stroke(session.agent.color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
          .rotationEffect(.degrees(-90))
        AgentGlyph(agent: session.agent, size: 22)
      }
      .frame(width: 64, height: 64)
      VStack(alignment: .leading, spacing: 3) {
        Text(verbatim: session.agent.name)
          .panelFont(.headline)
        Text(Self.status(of: session))
          .panelFont(.callout, weight: .medium)
          .foregroundStyle(session.agent.color)
          .lineLimit(1)
        if let fraction = session.contextFraction {
          Text(
            "\(Text(fraction, format: .percent.precision(.fractionLength(0)))) of the context window used",
            comment: "How full an AI agent session's context is"
          )
          .panelFont(.caption)
          .foregroundStyle(.secondary)
        } else {
          Text("Context use shows after the first answer.")
            .panelFont(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  static func status(of session: ClaudeCodeService.Session) -> String {
    switch session.state {
    case .working: session.step ?? AgentStep.thinking
    case .waitingPermission:
      String(localized: "Waiting for permission", comment: "AI agent needs approval")
    case .waitingInput: String(localized: "Waiting for you", comment: "AI agent needs input")
    case .done: String(localized: "Done", comment: "Claude Code finished")
    case .failed(let error): String(localized: "Error: \(error)", comment: "AI agent failed")
    case .ended: String(localized: "Session ended", comment: "AI agent session closed")
    }
  }

  static func symbol(of session: ClaudeCodeService.Session) -> String {
    switch session.state {
    case .working: "play.fill"
    case .waitingPermission: "hand.raised.fill"
    case .waitingInput: "bubble.left.fill"
    case .done: "checkmark.circle.fill"
    case .failed: "exclamationmark.triangle.fill"
    case .ended: "stop.circle"
    }
  }
}

extension Agent {
  /// Claude in a warm orange, Codex in a cool blue, so two sessions are told apart.
  var color: Color {
    switch self {
    case .claude: Color(red: 0.85, green: 0.47, blue: 0.34)
    case .codex: Color(red: 0.55, green: 0.66, blue: 1.0)
    }
  }
}
