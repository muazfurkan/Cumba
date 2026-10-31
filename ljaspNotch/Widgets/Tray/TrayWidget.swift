import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// A shelf for files: drop files on it, drag them out elsewhere, share with AirDrop.
/// Only references are kept (paths in UserDefaults); files are never copied or moved.
@MainActor
@Observable
final class TrayWidget: NotchWidget {
  static let kind = "tray"
  static var title: String { String(localized: "Tray", comment: "Widget name") }
  static let symbol = "tray"
  static let size = WidgetSize.regular
  static var summary: String {
    String(localized: "Keep dropped files at hand or AirDrop them", comment: "Widget description")
  }

  static let maxItems = 20
  private static let itemsKey = "tray.items"

  private(set) var items: [URL] = []
  @ObservationIgnored private let defaults: UserDefaults

  required convenience init(context: WidgetContext) {
    self.init(defaults: .standard)
  }

  init(defaults: UserDefaults) {
    self.defaults = defaults
    let paths = defaults.stringArray(forKey: Self.itemsKey) ?? []
    items = paths.map { URL(filePath: $0) }
      .filter { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }
  }

  func makeView() -> AnyView {
    AnyView(TrayView(tray: self))
  }

  func add(_ urls: [URL]) {
    var files: [URL] = []
    for url in urls where url.isFileURL && !items.contains(url) && !files.contains(url) {
      files.append(url)
    }
    guard !files.isEmpty else { return }
    items = Array((items + files).suffix(Self.maxItems))
    save()
  }

  func remove(_ url: URL) {
    items.removeAll { $0 == url }
    save()
  }

  func clear() {
    items = []
    save()
  }

  func airDrop(_ urls: [URL]) {
    NSSharingService(named: .sendViaAirDrop)?.perform(withItems: urls)
  }

  func reveal(_ url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

  private func save() {
    defaults.set(items.map { $0.path(percentEncoded: false) }, forKey: Self.itemsKey)
  }
}

private struct TrayView: View {
  let tray: TrayWidget
  @State private var isTargeted = false

  var body: some View {
    WidgetCard {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Label("Tray", systemImage: "tray")
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
          if !tray.items.isEmpty {
            Button {
              tray.airDrop(tray.items)
            } label: {
              Image(systemName: "dot.radiowaves.left.and.right")
            }
            .help(Text("Send All with AirDrop"))
            .accessibilityLabel(Text("Send All with AirDrop"))
            Button {
              tray.clear()
            } label: {
              Image(systemName: "xmark.circle")
            }
            .help(Text("Clear Tray"))
            .accessibilityLabel(Text("Clear Tray"))
          }
        }
        .buttonStyle(.plain)

        if tray.items.isEmpty {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .foregroundStyle(.secondary.opacity(isTargeted ? 1 : 0.5))
            .overlay {
              Text("Drop files here")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } else {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
              ForEach(tray.items, id: \.self) { url in
                TrayItem(url: url, tray: tray)
              }
            }
          }
        }
      }
    }
    .dropDestination(for: URL.self) { urls, _ in
      tray.add(urls)
      return true
    } isTargeted: {
      isTargeted = $0
    }
  }
}

private struct TrayItem: View {
  let url: URL
  let tray: TrayWidget

  var body: some View {
    VStack(spacing: 2) {
      Image(nsImage: NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false)))
        .resizable()
        .frame(width: 36, height: 36)
      Text(url.lastPathComponent)
        .font(.system(size: 9))
        .lineLimit(1)
        .truncationMode(.middle)
        .frame(width: 56)
    }
    .contentShape(Rectangle())
    .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
    .contextMenu {
      Button("Open") { NSWorkspace.shared.open(url) }
      Button("Show in Finder") { tray.reveal(url) }
      Button("Send with AirDrop") { tray.airDrop([url]) }
      Divider()
      Button("Remove from Tray") { tray.remove(url) }
    }
    .help(url.lastPathComponent)
    .accessibilityElement(children: .combine)
  }
}
