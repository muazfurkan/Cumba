import AppKit
import CoreLocation
import Foundation
import Testing

@testable import Cumba

@MainActor
struct PomodoroTests {
  private func makeWidget() throws -> (PomodoroWidget, UserDefaults, String) {
    let suite = "PomodoroTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    return (
      PomodoroWidget(defaults: defaults, liveActivities: LiveActivityCenter()), defaults, suite
    )
  }

  @Test func roundsFollowFocusBreakAndALongBreakAfterFour() throws {
    let (widget, defaults, suite) = try makeWidget()
    defer { defaults.removePersistentDomain(forName: suite) }
    var rounds: [PomodoroWidget.Round] = []
    for _ in 0..<8 {
      rounds.append(widget.round)
      widget.advance(countingFocus: true)
    }
    #expect(
      rounds == [
        .focus, .shortBreak, .focus, .shortBreak, .focus, .shortBreak, .focus, .longBreak,
      ])
    #expect(widget.round == .focus)
    #expect(widget.finishedInSet == 0)
    #expect(widget.finishedToday == 4)
  }

  @Test func skippedFocusDoesNotCount() throws {
    let (widget, defaults, suite) = try makeWidget()
    defer { defaults.removePersistentDomain(forName: suite) }
    widget.skip()
    #expect(widget.round == .shortBreak)
    #expect(widget.finishedToday == 0)
  }

  @Test func lengthsPersist() throws {
    let (widget, defaults, suite) = try makeWidget()
    defer { defaults.removePersistentDomain(forName: suite) }
    widget.focusMinutes = 50
    #expect(
      PomodoroWidget(defaults: defaults, liveActivities: LiveActivityCenter()).focusMinutes == 50)
  }
}

@MainActor
struct KeepAwakeTests {
  @Test func turnsOnAndOff() {
    let center = LiveActivityCenter()
    let widget = KeepAwakeWidget(
      context: WidgetContext(
        liveActivities: center, media: MediaCoordinator(providers: []),
        claude: ClaudeCodeService(liveActivities: center), openSettings: { _ in }))
    widget.turnOn(minutes: 30)
    #expect(widget.isOn)
    #expect(widget.endsAt != nil)
    #expect(center.contains("keepAwake"))
    widget.turnOff()
    #expect(!widget.isOn)
    #expect(!center.contains("keepAwake"))
  }
}

@MainActor
private func makeContext(panel: PanelControl = PanelControl()) -> WidgetContext {
  let center = LiveActivityCenter()
  return WidgetContext(
    liveActivities: center, media: MediaCoordinator(providers: []),
    claude: ClaudeCodeService(liveActivities: center), panel: panel, openSettings: { _ in })
}

@MainActor
struct ClipboardHistoryTests {
  @Test func keepsNewestFirstWithoutDuplicates() {
    let widget = ClipboardHistoryWidget(context: makeContext())
    defer { widget.shutdown() }
    widget.record(.text("one"), from: nil)
    widget.record(.text("two"), from: "com.apple.Notes")
    widget.record(.text("one"), from: nil)
    #expect(widget.items.map(\.content) == [.text("one"), .text("two")])
    #expect(widget.items[1].appBundleID == "com.apple.Notes")
  }

  @Test func staysWithinTheLimits() {
    let widget = ClipboardHistoryWidget(context: makeContext())
    defer { widget.shutdown() }
    for index in 0..<(ClipboardHistoryWidget.maxEntries + 5) {
      widget.record(.text("item \(index)"), from: nil)
    }
    #expect(widget.items.count == ClipboardHistoryWidget.maxEntries)
    let long = ClipboardItem.content(
      of: String(repeating: "x", count: ClipboardItem.maxLength + 10))
    #expect(long == .text(String(repeating: "x", count: ClipboardItem.maxLength)))
  }

  @Test func singleWebAddressesAreLinks() throws {
    let url = try #require(URL(string: "https://example.com/a?b=1"))
    #expect(ClipboardItem.content(of: "  https://example.com/a?b=1 \n") == .link(url))
    #expect(
      ClipboardItem.content(of: "see https://example.com") == .text("see https://example.com"))
    #expect(ClipboardItem.content(of: "file:///etc/hosts") == .text("file:///etc/hosts"))
    #expect(ClipboardItem.content(of: "   ") == nil)
  }

  @Test func readsFilesTextAndImagesAndSkipsPrivateItems() throws {
    let pasteboard = NSPasteboard(name: .init("CumbaTests-\(UUID().uuidString)"))
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("hello", forType: .string)
    #expect(ClipboardItem.read(from: pasteboard) == .text("hello"))

    let file = URL(filePath: "/tmp/report.pdf")
    pasteboard.clearContents()
    pasteboard.writeObjects([file as NSURL])
    pasteboard.setString("report.pdf", forType: .string)
    #expect(ClipboardItem.read(from: pasteboard) == .files([file]))

    let bitmap = try #require(
      NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 3, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0))
    let png = try #require(bitmap.representation(using: .png, properties: [:]))
    pasteboard.clearContents()
    pasteboard.setData(png, forType: .png)
    #expect(ClipboardItem.read(from: pasteboard) == .image(png, .png))

    pasteboard.clearContents()
    pasteboard.setString("hunter2", forType: .string)
    pasteboard.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
    #expect(ClipboardItem.read(from: pasteboard) == nil)
  }

  @Test func onlyFilesMarkedAsScreenCapturesCount() throws {
    let folder = FileManager.default.temporaryDirectory
      .appending(path: "ScreenshotTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let shot = folder.appending(path: "Screenshot 1.png")
    let other = folder.appending(path: "photo.png")
    let recording = folder.appending(path: "Recording.mov")
    for url in [shot, other, recording] {
      try Data([0]).write(to: url)
    }
    for url in [shot, recording] {
      let value: [UInt8] = [1]
      #expect(
        setxattr(
          url.path(percentEncoded: false), "com.apple.metadata:kMDItemIsScreenCapture", value,
          value.count, 0, 0) == 0)
    }
    #expect(
      ScreenshotWatcher.screenshots(in: folder, excluding: []).map(\.lastPathComponent)
        == [shot.lastPathComponent])
    #expect(ScreenshotWatcher.screenshots(in: folder, excluding: [shot.lastPathComponent]).isEmpty)
  }
}

@MainActor
struct TeleprompterTests {
  @Test func runningKeepsThePanelOpenAndHidden() throws {
    let suite = "TeleprompterTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let panel = PanelControl()
    var keptOpen = false
    var hidden = false
    panel.keepOpen = { keptOpen = $0 }
    panel.hideFromCapture = { hidden = $0 }
    let widget = TeleprompterWidget(defaults: defaults, panel: panel)
    widget.start()
    #expect(!widget.isRunning)  // No script yet.
    widget.text = "Hello"
    widget.start()
    #expect(widget.isRunning && keptOpen && hidden)
    widget.pause()
    #expect(!widget.isRunning && !keptOpen && !hidden)
    #expect(widget.offset(at: .now) >= 0)
    widget.restart()
    #expect(widget.offset(at: .now) == 0)
  }
}

@MainActor
struct NotesTests {
  @Test func savesAndLoads() async throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "notes-\(UUID()).txt")
    defer { try? FileManager.default.removeItem(at: url) }
    let widget = NotesWidget(fileURL: url, panel: PanelControl())
    await widget.load()
    widget.text = "Buy milk"
    widget.shutdown()
    try await Task.sleep(for: .milliseconds(300))
    let again = NotesWidget(fileURL: url, panel: PanelControl())
    await again.load()
    #expect(again.text == "Buy milk")
    let permissions =
      try FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))[
        .posixPermissions] as? Int
    #expect(permissions == 0o600)
  }
}

struct MeetingLinkTests {
  @Test func findsKnownMeetingServices() throws {
    let zoom = try #require(URL(string: "https://us02web.zoom.us/j/123?pwd=x"))
    #expect(MeetingLink.find(url: zoom, texts: []) == zoom)
    let found = MeetingLink.find(
      url: nil, texts: [nil, "Room 4", "Join: https://meet.google.com/abc-defg-hij thanks"])
    #expect(found?.host() == "meet.google.com")
  }

  @Test func ignoresOtherOrInsecureLinks() throws {
    #expect(MeetingLink.find(url: nil, texts: ["See https://example.com/zoom.us"]) == nil)
    let insecure = try #require(URL(string: "http://zoom.us/j/1"))
    #expect(MeetingLink.find(url: insecure, texts: []) == nil)
    #expect(MeetingLink.find(url: nil, texts: ["https://evilzoom.us/j/1"]) == nil)
  }
}

@MainActor
struct MediaSourceTests {
  @Test func disabledSourcesArePersistedAndIgnored() throws {
    let suite = "MediaSourceTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let media = MediaCoordinator(providers: [], defaults: defaults)
    media.disabledSources = [.spotify]
    media.receive(
      NowPlaying(
        source: .spotify, title: "Song", duration: 200, position: 10, positionTimestamp: .now,
        isPlaying: true), from: .spotify)
    #expect(media.current == nil)
    #expect(MediaCoordinator(providers: [], defaults: defaults).disabledSources == [.spotify])
  }
}

@MainActor
struct SystemIndicatorTests {
  @Test(arguments: [
    (Float(0), "speaker.slash.fill"), (0.2, "speaker.wave.1.fill"), (0.5, "speaker.wave.2.fill"),
    (0.9, "speaker.wave.3.fill"),
  ])
  func speakerSymbolFollowsTheLevel(volume: Float, symbol: String) {
    #expect(SystemIndicators.speakerSymbol(volume) == symbol)
  }

  /// Hosted runners may have no audio or camera devices; this only checks that starting and
  /// stopping the listeners is safe either way.
  @Test func monitorsStartAndStopCleanly() {
    let volume = VolumeMonitor()
    volume.start()
    _ = volume.level
    volume.stop()
    let privacy = PrivacyIndicatorMonitor()
    privacy.start()
    privacy.stop()
    #expect(privacy.state == PrivacyIndicatorMonitor.State())
  }
}

struct ResourceUsageTests {
  @Test func readsOwnUsage() {
    #expect(ResourceUsage.memory() > 1_000_000)
    #expect(ResourceUsage.cpuTime() > 0)
  }
}

@MainActor
struct ScriptActivityTests {
  private func message(_ json: String) throws -> ScriptActivityRoute.Message {
    try JSONDecoder().decode(ScriptActivityRoute.Message.self, from: Data(json.utf8))
  }

  @Test func validatesAndEscapes() throws {
    let activity = try #require(
      ScriptActivity(
        try message(
          #"{"id":"build","title":"Done‮evil","symbol":"no.such.symbol","progress":7,"duration":0}"#
        )))
    #expect(activity.id == "script.build")
    #expect(activity.title.contains("⟨U+202E⟩"))
    #expect(activity.symbol == "terminal")
    #expect(activity.progress == 1)
    #expect(activity.duration == ScriptActivity.durationRange.lowerBound)
  }

  @Test func rejectsBadMessages() throws {
    #expect(ScriptActivity(try message(#"{"id":"build"}"#)) == nil)
    #expect(ScriptActivity(try message(#"{"id":"../x","title":"t"}"#)) == nil)
    #expect(ScriptActivity(try message(#"{"id":"build","remove":true}"#))?.isRemoval == true)
  }

  @Test func showsAndRemoves() throws {
    let center = LiveActivityCenter()
    try #require(ScriptActivity(try message(#"{"id":"a","title":"Hi"}"#))).apply(to: center)
    #expect(center.contains("script.a"))
    try #require(ScriptActivity(try message(#"{"id":"a","remove":true}"#))).apply(to: center)
    #expect(!center.contains("script.a"))
  }
}

@MainActor
struct WeatherLocationTests {
  private let suiteName = "WeatherLocationTests-\(UUID().uuidString)"

  @Test func roundsTheLocationToAboutTenKilometers() {
    let rounded = LocationProvider.rounded(CLLocation(latitude: 41.0138, longitude: 28.9497))
    #expect(rounded.coordinate.latitude == 41.0)
    #expect(rounded.coordinate.longitude == 28.9)
  }

  @Test func usesTheMacsLocationUnlessAPlaceWasChosen() throws {
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    #expect(WeatherWidget(context: makeContext(), defaults: defaults).usesCurrentLocation)

    let place = WeatherService.Place(name: "İzmir", latitude: 38.4, longitude: 27.1)
    defaults.set(try JSONEncoder().encode(place), forKey: "weather.place")
    let widget = WeatherWidget(context: makeContext(), defaults: defaults)
    #expect(!widget.usesCurrentLocation)
    #expect(widget.place == place)
  }
}

@MainActor
struct WidgetGalleryTests {
  @Test func addsToTheOpenTabWhileThereIsRoom() async throws {
    let file = FileManager.default.temporaryDirectory
      .appending(path: "WidgetGalleryTests-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: file) }
    let registry = WidgetRegistry(
      context: makeContext(),
      types: [TimerWidget.self, KeepAwakeWidget.self, TeleprompterWidget.self])
    let store = LayoutStore(
      fileURL: file, knownKinds: registry.infos.map { ($0.kind, $0.size.units) },
      defaultKinds: [TimerWidget.kind])
    await store.load()
    let center = LiveActivityCenter()
    let host = WidgetHost(
      layoutStore: store, registry: registry, liveActivities: center,
      claude: ClaudeCodeService(liveActivities: center))

    #expect(host.freeUnits == WidgetLayout.unitsPerTab - 2)
    #expect(host.addableInfos.map(\.kind) == [KeepAwakeWidget.kind, TeleprompterWidget.kind])
    host.showGallery(true)
    host.add(TeleprompterWidget.kind)
    #expect(!host.isShowingGallery)
    #expect(host.selectedTab?.widgets == [TimerWidget.kind, TeleprompterWidget.kind])
    #expect(host.freeUnits == 1)
    host.add(KeepAwakeWidget.kind)
    #expect(host.freeUnits == 0)
    #expect(host.addableInfos.isEmpty)
    host.remove(TeleprompterWidget.kind)
    #expect(host.freeUnits == 3)
    #expect(host.addableInfos.map(\.kind) == [TeleprompterWidget.kind])

    host.showGallery(true)
    host.panelOpenChanged(false)
    #expect(!host.isShowingGallery)

    // The same widget can sit in another tab too.
    let second = store.addTab(title: "Agents")
    host.select(second)
    #expect(host.addableInfos.contains { $0.kind == TimerWidget.kind })
    host.add(TimerWidget.kind)
    #expect(store.layout.tabs.filter { $0.widgets.contains(TimerWidget.kind) }.count == 2)
    host.remove(TimerWidget.kind)
    #expect(store.layout.tabs[0].widgets.contains(TimerWidget.kind))
  }

  @Test func editsTabsAndSizesThePanelToTheOpenTab() async throws {
    let file = FileManager.default.temporaryDirectory
      .appending(path: "TabEditTests-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: file) }
    let registry = WidgetRegistry(
      context: makeContext(),
      types: [TimerWidget.self, KeepAwakeWidget.self, TeleprompterWidget.self])
    let store = LayoutStore(
      fileURL: file, knownKinds: registry.infos.map { ($0.kind, $0.size.units) },
      defaultKinds: [TimerWidget.kind, KeepAwakeWidget.kind, TeleprompterWidget.kind])
    await store.load()
    let center = LiveActivityCenter()
    let host = WidgetHost(
      layoutStore: store, registry: registry, liveActivities: center,
      claude: ClaudeCodeService(liveActivities: center))

    // A full tab uses the whole width; a single widget gets four units.
    #expect(host.preferredPanelWidth(maxWidth: 640) == 640)
    host.addTab()
    let single = host.selectedTab?.id
    host.add(TimerWidget.kind)
    let unit = (640.0 - 56 - 50) / 6
    #expect(abs(host.preferredPanelWidth(maxWidth: 640) - (56 + unit * 4 + 30)) < 0.01)
    host.showGallery(true)
    #expect(host.preferredPanelWidth(maxWidth: 640) == 640)
    host.showGallery(false)

    host.moveSelectedTab(by: -1)
    #expect(store.layout.tabs.first?.id == single)
    host.select(store.layout.tabs[1].id)
    host.moveWidget(TeleprompterWidget.kind, by: -1)
    #expect(host.selectedTab?.widgets.last == KeepAwakeWidget.kind)
    host.select(try #require(single))
    host.deleteSelectedTab()
    #expect(store.layout.tabs.count == 1)
    #expect(host.selectedTab?.id == store.layout.tabs.first?.id)
  }
}
