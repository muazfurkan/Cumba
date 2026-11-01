import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Themes and tab styles as cards, theme file actions, the panel's size and the theme
/// editor. Every change shows live in the panel, which stays open while this page is visible.
struct AppearanceSettingsView: View {
  let info: SettingsPageInfo
  let themes: ThemeStore
  let settings: AppSettings
  @State private var errorMessage: String?
  @State private var isNamingTheme = false
  @State private var newThemeName = ""

  private var current: Theme { themes.current }
  private var isBuiltIn: Bool { themes.isBuiltIn(current) }

  var body: some View {
    SettingsForm(info: info) {
      Section("Theme") {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 12)], spacing: 14) {
          ForEach(themes.themes) { theme in
            ChoiceCard(
              title: theme.displayName, isSelected: theme.id == themes.selectedID,
              select: { themes.select(theme.id) }
            ) {
              ThemePreview(theme: theme)
            }
          }
        }
        .padding(.vertical, 4)
        HStack {
          Button("New Theme…") {
            newThemeName = copyName
            isNamingTheme = true
          }
          // Built-in themes can't be deleted, only changed and restored.
          if !isBuiltIn {
            Button("Delete", role: .destructive) {
              themes.delete(current)
            }
          }
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
      Section {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 14) {
          ForEach(AppSettings.TabBarStyle.allCases, id: \.self) { style in
            ChoiceCard(
              title: style.title, isSelected: settings.tabBarStyle == style,
              select: { settings.tabBarStyle = style }
            ) {
              TabStylePreview(style: style)
            }
          }
        }
        .padding(.vertical, 4)
      } header: {
        Text("Tabs")
      } footer: {
        Text("Where the open panel's tabs are and how they look.")
      }
      Section {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 14) {
          ForEach(AppSettings.WidgetStyle.allCases, id: \.self) { style in
            ChoiceCard(
              title: style.title, isSelected: settings.widgetStyle == style,
              select: { settings.widgetStyle = style }
            ) {
              WidgetStylePreview(style: style)
            }
          }
        }
        .padding(.vertical, 4)
      } header: {
        Text("Widgets")
      } footer: {
        Text("How widgets side by side are set apart.")
      }
      PanelSizeSection(size: Bindable(settings).panelSize) { preview in
        settings.notchPreview = preview
      }
      ThemeEditorSections(theme: themeBinding)
    }
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

extension AppSettings.WidgetStyle {
  var title: String {
    switch self {
    case .lines: String(localized: "Lines", comment: "Widget style: a faint line between widgets")
    case .cards: String(localized: "Cards", comment: "Widget style: each widget on a card")
    }
  }
}
