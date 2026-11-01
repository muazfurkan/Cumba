import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Theme picker, theme file actions and the editor. Every change shows live in the panel,
/// which stays open while this tab is visible.
struct AppearanceSettingsView: View {
  let themes: ThemeStore
  let settings: AppSettings
  @State private var errorMessage: String?
  @State private var isNamingTheme = false
  @State private var newThemeName = ""

  private var current: Theme { themes.current }
  private var isBuiltIn: Bool { themes.isBuiltIn(current) }

  var body: some View {
    Form {
      PanelSizeSection(size: Bindable(settings).panelSize) { preview in
        settings.notchPreview = preview
      }
      Section("Theme") {
        Picker("Theme", selection: selection) {
          ForEach(themes.themes) { theme in
            Text(theme.displayName).tag(theme.id)
          }
        }
        HStack {
          Button("New Theme…") {
            newThemeName = copyName
            isNamingTheme = true
          }
          Button("Delete", role: .destructive) {
            themes.delete(current)
          }
          .disabled(isBuiltIn)
          Spacer()
          Button("Import…", action: importTheme)
          Button("Export…", action: exportTheme)
        }
        .alert("New Theme", isPresented: $isNamingTheme) {
          TextField("Name", text: $newThemeName)
          Button("Create", action: createTheme)
          Button("Cancel", role: .cancel) {}
        } message: {
          Text("It starts from \(current.displayName).", comment: "New theme: the theme it copies")
        }
        if isBuiltIn {
          HStack {
            Text("Built-in themes keep their name. Your changes are saved with them.")
              .foregroundStyle(.secondary)
            Spacer()
            Button("Restore Defaults") {
              themes.restoreDefaults(current)
            }
            .disabled(!themes.isChanged(current))
          }
        } else {
          TextField("Name", text: themeBinding.name)
        }
      }
      ThemeEditorSections(theme: themeBinding)
    }
    .formStyle(.grouped)
    .frame(width: 520, height: 620)
    .onAppear { settings.isPreviewingAppearance = true }
    .onDisappear {
      settings.isPreviewingAppearance = false
      settings.notchPreview = nil
    }
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

  /// Edits apply live; a built-in theme keeps its name.
  private var themeBinding: Binding<Theme> {
    Binding(get: { themes.current }, set: { themes.update($0) })
  }

  /// Makes a user theme from the current one under the name typed in.
  private func createTheme() {
    let name = newThemeName.trimmingCharacters(in: .whitespacesAndNewlines)
    themes.duplicate(current, name: name.isEmpty ? copyName : name)
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
