import AppKit
import SwiftUI

/// The history as a row of cards, newest first, that scrolls sideways.
struct ClipboardView: View {
  let widget: ClipboardHistoryWidget
  @Environment(\.showsDetailedWidget) private var isDetailed

  var body: some View {
    WidgetCard {
      VStack(alignment: .leading, spacing: 6) {
        Label("Clipboard", systemImage: "doc.on.clipboard")
          .panelFont(.caption)
          .foregroundStyle(.secondary)
        if widget.items.isEmpty {
          Text("What you copy appears here.")
            .panelFont(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          ScrollView(.horizontal) {
            LazyHStack(spacing: 8) {
              ForEach(widget.items) { item in
                ClipCard(
                  item: item, isCopied: widget.lastCopiedID == item.id,
                  width: isDetailed ? 150 : 118
                ) {
                  widget.copy(item)
                }
                .contextMenu {
                  Button("Copy") { widget.copy(item) }
                  if case .screenshot(let url) = item.content {
                    Button("Show in Finder") {
                      NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                  }
                  Button("Remove", role: .destructive) { widget.remove(item) }
                }
              }
            }
          }
          .scrollIndicators(.never)
        }
      }
    }
  }
}

/// One copied item: where it came from and when on top, a preview below. Clicking copies it
/// again.
private struct ClipCard: View {
  let item: ClipboardItem
  let isCopied: Bool
  let width: CGFloat
  let copy: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: copy) {
      VStack(alignment: .leading, spacing: 0) {
        header
        preview
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
      .frame(width: width)
      .frame(maxHeight: .infinity)
      .background(.white.opacity(isHovered ? 0.13 : 0.07))
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(isCopied ? Color.green.opacity(0.8) : .white.opacity(0.08))
      }
      .overlay(alignment: .bottomTrailing) {
        if isCopied {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 15))
            .foregroundStyle(.white, .green)
            .padding(6)
            .accessibilityLabel(Text("Copied"))
        }
      }
      .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
    .animation(.easeOut(duration: 0.12), value: isHovered)
    .help(Text("Copy again"))
  }

  private var header: some View {
    HStack(spacing: 5) {
      AppIcon(bundleID: item.appBundleID, fallback: item.content.symbol)
        .frame(width: 14, height: 14)
      // Narrow cards leave the kind to the icon and the color, so the time fits.
      if width >= 140 {
        Text(verbatim: item.content.title)
          .font(.system(size: 10, weight: .semibold))
          .lineLimit(1)
      }
      Spacer(minLength: 2)
      TimelineView(.everyMinute) { _ in
        Text(item.date, format: .relative(presentation: .named, unitsStyle: .narrow))
          .font(.system(size: 9))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .padding(.horizontal, 8)
    .frame(height: 24)
    .background(item.content.color.opacity(0.28))
  }

  @ViewBuilder private var preview: some View {
    switch item.content {
    case .text(let text):
      Text(verbatim: text)
        .font(.system(size: 11))
        .multilineTextAlignment(.leading)
        .padding(8)
    case .link(let url):
      VStack(alignment: .leading, spacing: 3) {
        Text(verbatim: url.host() ?? url.absoluteString)
          .font(.system(size: 12, weight: .semibold))
          .lineLimit(2)
        Text(verbatim: url.absoluteString)
          .font(.system(size: 10))
          .foregroundStyle(.blue)
          .lineLimit(3)
      }
      .padding(8)
    case .image, .screenshot:
      ImagePreview(item: item)
    case .files(let urls):
      VStack(alignment: .leading, spacing: 4) {
        Image(nsImage: NSWorkspace.shared.icon(forFile: urls[0].path(percentEncoded: false)))
          .resizable()
          .frame(width: 34, height: 34)
          .accessibilityHidden(true)
        Text(verbatim: urls[0].lastPathComponent)
          .font(.system(size: 11, weight: .medium))
          .lineLimit(2)
        if urls.count > 1 {
          Text(verbatim: "+\(urls.count - 1)")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
      }
      .padding(8)
    }
  }
}

/// The image filling the card, with its size in a corner. The image is drawn over a clear
/// view so filling never makes the card wider.
private struct ImagePreview: View {
  let item: ClipboardItem

  var body: some View {
    Color.clear
      .overlay {
        if let thumbnail = item.thumbnail {
          Image(decorative: thumbnail, scale: 1)
            .resizable()
            .scaledToFill()
        } else {
          Image(systemName: item.content.symbol)
            .font(.title2)
            .foregroundStyle(.secondary)
        }
      }
      .clipped()
      .overlay(alignment: .bottomLeading) {
        if let size = item.pixelSize {
          Text(verbatim: "\(Int(size.width))×\(Int(size.height))")
            .font(.system(size: 9, weight: .medium))
            .monospacedDigit()
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(6)
        }
      }
  }
}

/// The app an item came from, or a symbol for its kind.
private struct AppIcon: View {
  let bundleID: String?
  let fallback: String

  var body: some View {
    if let bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    {
      Image(nsImage: NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false)))
        .resizable()
        .accessibilityHidden(true)
    } else {
      Image(systemName: fallback)
        .font(.system(size: 10, weight: .semibold))
        .accessibilityHidden(true)
    }
  }
}

struct ClipboardSettingsView: View {
  let widget: ClipboardHistoryWidget

  var body: some View {
    Text(
      "While this widget is in the panel, Cumba checks once a second whether the clipboard changed and keeps your last \(ClipboardHistoryWidget.maxEntries) copies (text, links, images and files) in memory. Passwords and other items apps mark as private are skipped, and nothing is saved to disk. macOS may ask once whether Cumba may read what you copy."
    )
    .panelFont(.callout)
    .foregroundStyle(.secondary)
    .fixedSize(horizontal: false, vertical: true)
    Toggle(
      "Add new screenshots",
      isOn: Binding(
        get: { widget.includesScreenshots }, set: { widget.setIncludesScreenshots($0) }))
    Text(
      "Screenshots saved to \(ScreenshotWatcher.folder.lastPathComponent) are added as they appear; only their location is kept. macOS asks once for access to that folder."
    )
    .panelFont(.caption)
    .foregroundStyle(.secondary)
    .fixedSize(horizontal: false, vertical: true)
    if widget.screenshotsUnavailable {
      Text("Cumba can't read that folder. Allow it in Privacy & Security > Files and Folders.")
        .panelFont(.caption)
        .foregroundStyle(.orange)
      OpenPrivacySettings(pane: "Privacy_FilesAndFolders")
    }
    Button("Clear History", role: .destructive) { widget.clear() }
      .disabled(widget.items.isEmpty)
  }
}
