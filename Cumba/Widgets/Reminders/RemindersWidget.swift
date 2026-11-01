import EventKit
import Observation
import SwiftUI

/// To-dos from Apple Reminders: a list's open reminders with round checkboxes, and a line to
/// add one. Ticking or adding changes Reminders itself, so it syncs to your other devices.
@MainActor
@Observable
final class RemindersWidget: NotchWidget {
  static let kind = "reminders"
  static var title: String { String(localized: "To-dos", comment: "Widget name") }
  static let symbol = "checklist"
  static let size = WidgetSize.regular
  static var summary: String {
    String(
      localized: "Your Apple Reminders: tick them off and add new ones",
      comment: "Widget description")
  }

  private(set) var items: [ReminderItem] = []
  private(set) var list: ReminderList?
  private(set) var lists: [ReminderList] = []
  private(set) var hasAccess = RemindersService.hasAccess
  /// Reminders ticked a moment ago; they stay checked briefly before leaving the list.
  private(set) var ticked: Set<String> = []
  /// A new reminder being typed.
  var draft = ""

  /// The list shown; nil is the list new reminders go to by default.
  var listID: String? {
    didSet {
      defaults.set(listID, forKey: Self.listKey)
      reload()
    }
  }

  @ObservationIgnored private let service = RemindersService()
  @ObservationIgnored private let panel: PanelControl
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private var observer: NSObjectProtocol?

  private static let listKey = "reminders.list"

  required init(context: WidgetContext) {
    panel = context.panel
    defaults = .standard
    listID = defaults.string(forKey: Self.listKey)
  }

  func makeView() -> AnyView {
    AnyView(RemindersView(widget: self))
  }

  func makeSettingsView() -> AnyView? {
    AnyView(RemindersSettingsView(widget: self))
  }

  /// Watches Reminders only while the widget is on screen.
  func activate() {
    observer = NotificationCenter.default.addObserver(
      forName: .EKEventStoreChanged, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.reload() }
    }
    reload()
  }

  func deactivate() {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
    observer = nil
  }

  func shutdown() {
    deactivate()
  }

  func reload() {
    hasAccess = RemindersService.hasAccess
    guard hasAccess else { return }
    let wanted = listID
    Task {
      let list = await service.list(wanted)
      let lists = await service.lists()
      var items: [ReminderItem] = []
      if let list {
        items = await service.openReminders(in: list.id)
      }
      guard wanted == listID else { return }
      self.list = list
      self.lists = lists
      self.items = items
    }
  }

  func requestAccess() async {
    _ = await service.requestAccess()
    reload()
  }

  /// From the panel: closes it first, then shows the prompt.
  func requestAccessFromPanel() {
    panel.close()
    NSApp.activate()
    Task { await requestAccess() }
  }

  /// Checks a reminder off in Reminders; it stays ticked a moment, then leaves the list.
  func tick(_ item: ReminderItem) {
    guard !ticked.contains(item.id) else { return }
    ticked.insert(item.id)
    Task {
      do {
        try await service.complete(item.id)
      } catch {
        Log.widgets.error("Completing a reminder failed")
        ticked.remove(item.id)
        return
      }
      try? await Task.sleep(for: .milliseconds(700))
      withAnimation(.easeOut(duration: 0.2)) {
        items.removeAll { $0.id == item.id }
        ticked.remove(item.id)
      }
    }
  }

  /// Adds what was typed to the list.
  func addDraft() {
    let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty, let list else { return }
    draft = ""
    Task {
      do {
        try await service.add(title, to: list.id)
      } catch {
        Log.widgets.error("Adding a reminder failed")
      }
      reload()
    }
  }

  /// Tall enough for every open reminder, the header and the line to add one.
  func preferredContentHeight(width: CGFloat, textScale: CGFloat, isDetailed: Bool) -> CGFloat? {
    guard hasAccess, !items.isEmpty else { return nil }
    let row = 21 * textScale + 6
    return 20 + 20 * textScale + 6 + CGFloat(items.count + 1) * row
  }
}
