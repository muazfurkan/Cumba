import SwiftUI

/// A list from Apple Reminders like Apple's widget: its name and count in the list's color,
/// a round checkbox per reminder, overdue dates in red, and a line to add one.
struct RemindersView: View {
  @Bindable var widget: RemindersWidget
  @FocusState private var isAdding: Bool

  private var color: Color { widget.list?.color?.color ?? .blue }

  var body: some View {
    WidgetCard {
      VStack(alignment: .leading, spacing: 6) {
        if widget.hasAccess {
          WidgetHeader(
            verbatim: widget.list?.title ?? RemindersWidget.title,
            symbol: "checklist", color: color
          ) {
            if !widget.items.isEmpty {
              Text(verbatim: "\(widget.items.count)")
                .monospacedDigit()
            }
          }
          ScrollView {
            VStack(alignment: .leading, spacing: 6) {
              ForEach(widget.items) { item in
                row(item)
              }
              addRow
            }
          }
          .scrollIndicators(.never)
        } else {
          WidgetHeader("To-dos", symbol: "checklist", color: .blue)
          access
        }
      }
    }
  }

  private func row(_ item: ReminderItem) -> some View {
    let isTicked = widget.ticked.contains(item.id)
    return HStack(alignment: .firstTextBaseline, spacing: 8) {
      Button {
        widget.tick(item)
      } label: {
        Image(systemName: isTicked ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 15, weight: .regular))
          .foregroundStyle(isTicked ? color : .secondary)
          .contentTransition(.symbolEffect(.replace))
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Text("Complete"))
      VStack(alignment: .leading, spacing: 1) {
        Text(verbatim: item.title)
          .panelFont(.callout)
          .strikethrough(isTicked)
          .foregroundStyle(isTicked ? .secondary : .primary)
          .lineLimit(2)
        if let due = item.due {
          Text(verbatim: Self.when(due, hasTime: item.dueHasTime))
            .panelFont(.caption)
            .foregroundStyle(item.isOverdue() ? Color.red : Color.secondary)
        }
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var addRow: some View {
    HStack(spacing: 8) {
      Image(systemName: "plus.circle.fill")
        .font(.system(size: 15))
        .foregroundStyle(color)
        .accessibilityHidden(true)
      TextField(text: $widget.draft) {
        Text("New Reminder")
      }
      .textFieldStyle(.plain)
      .panelFont(.callout)
      .focused($isAdding)
      .onSubmit { widget.addDraft() }
      .onExitCommand { isAdding = false }
    }
  }

  @ViewBuilder private var access: some View {
    if RemindersService.accessWasDenied {
      Text("Reminders access is off. You can allow it in System Settings.")
        .panelFont(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      OpenPrivacySettings(pane: "Privacy_Reminders")
        .controlSize(.small)
    } else {
      Text("Tick off and add your Apple Reminders here.")
        .panelFont(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Button("Allow Reminders Access") { widget.requestAccessFromPanel() }
        .controlSize(.small)
    }
  }

  /// "Today 15:00", "Tomorrow", or the day and month, like Reminders.
  static func when(_ date: Date, hasTime: Bool) -> String {
    let calendar = Calendar.current
    let day =
      calendar.isDateInToday(date)
      ? String(localized: "Today", comment: "Reminder due today")
      : calendar.isDateInTomorrow(date)
        ? String(localized: "Tomorrow", comment: "Reminder due tomorrow")
        : date.formatted(.dateTime.day().month(.abbreviated))
    return hasTime ? "\(day) \(date.formatted(date: .omitted, time: .shortened))" : day
  }
}

/// Access and the list to show, in Settings where the prompt can't hide behind the panel.
struct RemindersSettingsView: View {
  @Bindable var widget: RemindersWidget

  var body: some View {
    if widget.hasAccess {
      Picker("List", selection: $widget.listID) {
        Text("Default list").tag(String?.none)
        ForEach(widget.lists) { list in
          Text(verbatim: list.title).tag(Optional(list.id))
        }
      }
    } else if RemindersService.accessWasDenied {
      Text("Reminders access is off.")
        .foregroundStyle(.secondary)
      OpenPrivacySettings(pane: "Privacy_Reminders")
    } else {
      Button("Allow Reminders Access") { Task { await widget.requestAccess() } }
    }
  }
}
