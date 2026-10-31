import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Theme picker, theme file actions and the editor. Every change shows live in the panel,
/// which stays open while this tab is visible.
struct AppearanceSettingsView: View {
  let themes: ThemeStore
  let settings: AppSettings
  @State private var errorMessage: String?

  private var current: Theme { themes.current }
  private var isBuiltIn: Bool { themes.isBuiltIn(current) }

  var body: some View {
    Form {
      Section("Theme") {
        Picker("Theme", selection: selection) {
          ForEach(themes.themes) { theme in
            Text(theme.displayName).tag(theme.id)
          }
        }
        HStack {
          Button("Duplicate") {
            themes.duplicate(current, name: copyName)
          }
          Button("Delete", role: .destructive) {
            themes.delete(current)
          }
          .disabled(isBuiltIn)
          Spacer()
          Button("Import…", action: importTheme)
          Button("Export…", action: exportTheme)
        }
        if isBuiltIn {
          Text(
            "Built-in themes stay as they are. Change anything below and it's saved as a copy you can rename."
          )
          .foregroundStyle(.secondary)
        } else {
          TextField("Name", text: themeBinding.name)
        }
      }
      ThemeEditorSections(theme: themeBinding)
    }
    .formStyle(.grouped)
    .frame(width: 520, height: 620)
    .onAppear { settings.isPreviewingAppearance = true }
    .onDisappear { settings.isPreviewingAppearance = false }
    .alert(
      "The theme file couldn't be used.",
      isPresented: Binding(
        get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    ) {
      Button("OK") {}
    } message: {
      Text(errorMessage ?? "")
    }
  }

  private var selection: Binding<String> {
    Binding(get: { themes.selectedID }, set: { themes.select($0) })
  }

  private var copyName: String {
    String(localized: "\(current.displayName) Copy", comment: "Duplicated theme")
  }

  /// Edits to a built-in theme go to a new copy, which is then selected.
  private var themeBinding: Binding<Theme> {
    Binding(get: { themes.current }, set: { themes.edit($0, copyName: copyName) })
  }

  private func importTheme() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    Task {
      do {
        try await themes.importTheme(from: url)
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  private func exportTheme() {
    let theme = current
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.nameFieldStringValue = "\(theme.displayName).json"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    Task {
      do {
        try await themes.export(theme, to: url)
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }
}
