import AppKit

/// Main menu. It is never visible (LSUIElement), but it provides the standard
/// shortcuts (⌘Q, ⌘W, copy and paste) while the Settings window is focused.
@MainActor
enum MainMenu {
  static func make() -> NSMenu {
    let mainMenu = NSMenu()
    mainMenu.addItem(
      submenu(
        String(localized: "ljaspNotch"),
        [
          item(String(localized: "Quit ljaspNotch"), #selector(NSApplication.terminate(_:)), "q")
        ]))
    mainMenu.addItem(
      submenu(
        String(localized: "Edit"),
        [
          item(String(localized: "Cut"), #selector(NSText.cut(_:)), "x"),
          item(String(localized: "Copy"), #selector(NSText.copy(_:)), "c"),
          item(String(localized: "Paste"), #selector(NSText.paste(_:)), "v"),
          item(String(localized: "Select All"), #selector(NSText.selectAll(_:)), "a"),
        ]))
    mainMenu.addItem(
      submenu(
        String(localized: "Window"),
        [
          item(String(localized: "Close"), #selector(NSWindow.performClose(_:)), "w"),
          item(String(localized: "Minimize"), #selector(NSWindow.performMiniaturize(_:)), "m"),
        ]))
    return mainMenu
  }

  private static func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
    NSMenuItem(title: title, action: action, keyEquivalent: key)
  }

  private static func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
    let menu = NSMenu(title: title)
    for item in items {
      menu.addItem(item)
    }
    let item = NSMenuItem()
    item.submenu = menu
    return item
  }
}
