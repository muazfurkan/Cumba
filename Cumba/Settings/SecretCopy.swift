import AppKit

/// Copies a token marked as concealed, so clipboard managers and Universal Clipboard skip
/// it, and clears it again after a minute if nothing else was copied since.
@MainActor
enum SecretCopy {
  static func copy(_ secret: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(secret, forType: .string)
    pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
    let changeCount = pasteboard.changeCount
    Task {
      try? await Task.sleep(for: .seconds(60))
      if NSPasteboard.general.changeCount == changeCount {
        NSPasteboard.general.clearContents()
      }
    }
  }
}
