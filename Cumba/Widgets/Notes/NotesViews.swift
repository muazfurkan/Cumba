import SwiftUI

/// Recent Apple Notes like Apple's Notes widget: each note's title in bold, when it changed
/// and the start of its text in gray. "+" types a new note; clicking a note opens it in Notes.
struct NotesView: View {
  @Bindable var widget: NotesWidget
  @Environment(\.showsDetailedWidget) private var isDetailed
  @State private var isWriting = false
  @FocusState private var isFocused: Bool

  var body: some View {
    WidgetCard {
      VStack(alignment: .leading, spacing: 6) {
        WidgetHeader("Notes", symbol: "note.text", color: .yellow) {
          if widget.status == .ready {
            Button {
              withAnimation(.easeOut(duration: 0.15)) { isWriting.toggle() }
            } label: {
              Image(systemName: isWriting ? "xmark" : "square.and.pencil")
            }
            .buttonStyle(.plain)
            .help(isWriting ? Text("Cancel") : Text("New Note"))
            .accessibilityLabel(isWriting ? Text("Cancel") : Text("New Note"))
          }
        }
        content
      }
    }
  }

  @ViewBuilder private var content: some View {
    switch widget.status {
    case .notConnected:
      message(
        Text("See and add to your Apple Notes here."),
        button: Button("Connect Notes") { widget.connectFromPanel() })
    case .denied:
      message(
        Text(
          "Cumba can't read Notes. Allow it in System Settings > Privacy & Security > Automation."),
        button: Button("Open Settings") { widget.showSettings() })
    case .failed:
      message(
        Text("Notes didn't answer."),
        button: Button("Try Again") { Task { await widget.refresh() } })
    case .loading where widget.notes.isEmpty:
      ProgressView()
        .controlSize(.small)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    default:
      if isWriting {
        editor
      } else if widget.notes.isEmpty {
        Text("No notes yet.")
          .panelFont(.callout)
          .foregroundStyle(.secondary)
      } else {
        list
      }
    }
  }

  private var list: some View {
    VStack(alignment: .leading, spacing: 7) {
      ForEach(widget.notes.prefix(isDetailed ? NotesWidget.shownNotes : 3)) { note in
        Button {
          widget.open(note)
        } label: {
          VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: note.title.isEmpty ? " " : note.title)
              .panelFont(.callout, weight: .semibold)
              .lineLimit(1)
            HStack(spacing: 5) {
              Text(verbatim: Self.when(note.modified))
                .monospacedDigit()
              Text(verbatim: note.preview)
                .lineLimit(1)
            }
            .panelFont(.caption)
            .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Text("Open in Notes"))
      }
    }
    .frame(maxHeight: .infinity, alignment: .top)
  }

  private var editor: some View {
    VStack(alignment: .trailing, spacing: 6) {
      TextEditor(text: $widget.draft)
        .panelFont(.callout)
        .tint(.yellow)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.never)
        .focused($isFocused)
        .overlay(alignment: .topLeading) {
          if widget.draft.isEmpty {
            Text("The first line becomes the title.")
              .panelFont(.callout)
              .foregroundStyle(.tertiary)
              .padding(.leading, 5)
              .allowsHitTesting(false)
          }
        }
        .onAppear { isFocused = true }
        .onExitCommand {
          isWriting = false
          widget.closePanel()
        }
      Button("Save to Notes") {
        Task {
          if await widget.saveDraft() {
            isWriting = false
          }
        }
      }
      .keyboardShortcut(.return, modifiers: .command)
      .controlSize(.small)
      .disabled(widget.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
  }

  private func message(_ text: Text, button: Button<Text>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      text
        .panelFont(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      button
        .controlSize(.small)
    }
  }

  /// The time for today, the day and month before that, like Apple Notes.
  static func when(_ date: Date) -> String {
    Calendar.current.isDateInToday(date)
      ? date.formatted(date: .omitted, time: .shortened)
      : date.formatted(.dateTime.day().month(.abbreviated))
  }
}

/// Connecting Notes from Settings, where the Automation prompt can't hide behind the panel.
struct NotesSettingsView: View {
  let widget: NotesWidget

  var body: some View {
    Text(
      "The Notes widget shows your most recent Apple Notes and makes new ones. Cumba reads Notes through AppleScript, starting Notes in the background when it isn't open, and never changes or deletes an existing note. Nothing leaves your Mac."
    )
    .panelFont(.callout)
    .foregroundStyle(.secondary)
    .fixedSize(horizontal: false, vertical: true)
    switch widget.status {
    case .notConnected, .failed:
      Button("Connect Notes") { Task { await widget.connect() } }
    case .denied:
      Text("Automation access to Notes is off.")
        .foregroundStyle(.secondary)
      OpenPrivacySettings(pane: "Privacy_Automation")
    case .loading, .ready:
      Label("Connected to Notes", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)
    }
  }
}
