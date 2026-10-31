import Observation
import SwiftUI

/// Scrolls a script right under the camera, so you keep eye contact while reading. The
/// text is edited in Settings. While it runs the panel stays open and, if chosen, is left
/// out of screen sharing and recordings. It only animates while running.
@MainActor
@Observable
final class TeleprompterWidget: NotchWidget {
  static let kind = "teleprompter"
  static var title: String { String(localized: "Teleprompter", comment: "Widget name") }
  static let symbol = "text.aligncenter"
  static let size = WidgetSize.wide
  static var summary: String {
    String(
      localized: "Scrolls your script under the camera while you talk",
      comment: "Widget description")
  }

  static let speedRange = 10.0...120.0
  static let fontSizeRange = 14.0...36.0

  var text: String {
    didSet { defaults.set(text, forKey: Key.text) }
  }
  /// Points per second.
  var speed: Double {
    didSet { defaults.set(speed, forKey: Key.speed) }
  }
  var fontSize: Double {
    didSet { defaults.set(fontSize, forKey: Key.fontSize) }
  }
  var hidesFromCapture: Bool {
    didSet { defaults.set(hidesFromCapture, forKey: Key.hidesFromCapture) }
  }

  private(set) var isRunning = false
  /// Scroll offset reached before the current run.
  private(set) var offsetBeforeRun: Double = 0
  private(set) var runStartedAt: Date?

  private enum Key {
    static let text = "teleprompter.text"
    static let speed = "teleprompter.speed"
    static let fontSize = "teleprompter.fontSize"
    static let hidesFromCapture = "teleprompter.hidesFromCapture"
  }

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let panel: PanelControl

  required convenience init(context: WidgetContext) {
    self.init(defaults: .standard, panel: context.panel)
  }

  init(defaults: UserDefaults, panel: PanelControl) {
    self.defaults = defaults
    self.panel = panel
    text = defaults.string(forKey: Key.text) ?? ""
    speed = (defaults.object(forKey: Key.speed) as? Double ?? 40).clamped(to: Self.speedRange)
    fontSize =
      (defaults.object(forKey: Key.fontSize) as? Double ?? 22).clamped(to: Self.fontSizeRange)
    hidesFromCapture = defaults.object(forKey: Key.hidesFromCapture) as? Bool ?? true
  }

  func makeView() -> AnyView {
    AnyView(TeleprompterView(widget: self))
  }

  func makeSettingsView() -> AnyView? {
    AnyView(TeleprompterSettingsView(widget: self))
  }

  func deactivate() {
    pause()
  }

  func shutdown() {
    pause()
  }

  func offset(at date: Date) -> Double {
    guard let runStartedAt else { return offsetBeforeRun }
    return offsetBeforeRun + date.timeIntervalSince(runStartedAt) * speed
  }

  func start() {
    guard !isRunning, !text.isEmpty else { return }
    runStartedAt = .now
    isRunning = true
    panel.keepOpen(true)
    panel.hideFromCapture(hidesFromCapture)
  }

  func pause() {
    guard isRunning else { return }
    offsetBeforeRun = offset(at: .now)
    runStartedAt = nil
    isRunning = false
    panel.keepOpen(false)
    panel.hideFromCapture(false)
  }

  func restart() {
    pause()
    offsetBeforeRun = 0
  }
}

private struct TeleprompterView: View {
  let widget: TeleprompterWidget
  @State private var textHeight: CGFloat = 0

  var body: some View {
    WidgetCard {
      HStack(alignment: .top, spacing: 10) {
        if widget.text.isEmpty {
          Text("Add your script in Settings > Widgets.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
          TimelineView(.animation(paused: !widget.isRunning)) { context in
            let offset = min(widget.offset(at: context.date), Double(textHeight))
            Text(widget.text)
              .font(.system(size: widget.fontSize, weight: .medium))
              .lineSpacing(widget.fontSize * 0.3)
              .multilineTextAlignment(.center)
              .frame(maxWidth: .infinity)
              .fixedSize(horizontal: false, vertical: true)
              .onGeometryChange(for: CGFloat.self) {
                $0.size.height
              } action: {
                textHeight = $0
              }
              .offset(y: -offset)
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
              .clipped()
              .mask(
                LinearGradient(
                  stops: [
                    .init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                    .init(color: .black, location: 0.85), .init(color: .clear, location: 1),
                  ], startPoint: .top, endPoint: .bottom))
          }
        }
        VStack(spacing: 6) {
          Button {
            widget.isRunning ? widget.pause() : widget.start()
          } label: {
            Image(systemName: widget.isRunning ? "pause.fill" : "play.fill")
              .contentTransition(.symbolEffect(.replace))
          }
          .buttonStyle(PanelButtonStyle(isSelected: true))
          .accessibilityLabel(widget.isRunning ? Text("Pause") : Text("Start"))
          .disabled(widget.text.isEmpty)
          Button {
            widget.restart()
          } label: {
            Image(systemName: "backward.end.fill")
          }
          .buttonStyle(PanelButtonStyle())
          .accessibilityLabel(Text("Back to Start"))
        }
      }
    }
  }
}

private struct TeleprompterSettingsView: View {
  @Bindable var widget: TeleprompterWidget

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Script")
      TextEditor(text: $widget.text)
        .font(.body)
        .frame(minHeight: 120)
        .scrollContentBackground(.hidden)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 6))
    }
    LabeledContent("Speed") {
      Slider(value: $widget.speed, in: TeleprompterWidget.speedRange)
    }
    LabeledContent("Text Size") {
      Slider(value: $widget.fontSize, in: TeleprompterWidget.fontSizeRange)
    }
    Toggle("Hide the panel from screen sharing while it runs", isOn: $widget.hidesFromCapture)
  }
}
