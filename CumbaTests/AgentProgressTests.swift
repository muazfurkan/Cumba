import Foundation
import Testing

@testable import Cumba

struct AgentStepTests {
  @Test func describesTools() {
    #expect(
      AgentStep.describe(
        toolName: "Edit", input: ["file_path": .string("/repo/Cumba/Notch.swift")], cwd: "/repo"
      )
      .contains("Notch.swift"))
    #expect(
      AgentStep.describe(
        toolName: "Bash", input: ["command": .string("xcodebuild test")], cwd: nil
      )
      .contains("xcodebuild test"))
    #expect(AgentStep.describe(toolName: nil, input: nil, cwd: nil) == AgentStep.thinking)
  }
}

struct TranscriptReaderTests {
  @Test func findsContextUseAndTitleFromTheEnd() {
    let lines = [
      #"{"type":"summary","summary":"Notch repo setup"}"#,
      #"{"type":"assistant","message":{"usage":{"input_tokens":10,"cache_read_input_tokens":40000,"cache_creation_input_tokens":2000,"output_tokens":300}}}"#,
      #"{"type":"user","message":{"content":"hi"}}"#,
      #"{"type":"assistant","message":{"usage":{"input_tokens":5,"cache_read_input_tokens":90000,"cache_creation_input_tokens":4995,"output_tokens":10}}}"#,
      "not json",
    ]
    let summary = TranscriptReader.parse(lines.joined(separator: "\n"))
    #expect(summary.title == "Notch repo setup")
    #expect(summary.contextTokens == 95000)
    #expect(summary.contextFraction == 0.475)
  }

  @Test func bigContextsUseTheMillionTokenWindow() {
    let line =
      #"{"type":"assistant","message":{"usage":{"input_tokens":1,"cache_read_input_tokens":499999}}}"#
    #expect(TranscriptReader.parse(line).contextLimit == 1_000_000)
  }

  @Test func readsOnlyTranscriptsUnderClaudeProjects() {
    let home = URL(filePath: "/Users/someone")
    #expect(
      TranscriptReader.allowedURL("/Users/someone/.claude/projects/-x/abc.jsonl", home: home)
        != nil)
    #expect(TranscriptReader.allowedURL("/Users/someone/.ssh/id_rsa", home: home) == nil)
    #expect(
      TranscriptReader.allowedURL("/Users/someone/.claude/projects/../secrets.jsonl", home: home)
        == nil)
    #expect(TranscriptReader.allowedURL(nil, home: home) == nil)
  }
}

@MainActor
struct AgentSessionTests {
  private func payload(_ event: String, _ extra: String = "") -> HookPayload? {
    HookPayload.decode(
      Data(
        #"{"session_id":"s1","hook_event_name":"\#(event)","cwd":"/repo/Cumba"\#(extra)}"#.utf8))
  }

  @Test func followsAWorkingSession() throws {
    let center = LiveActivityCenter()
    let service = ClaudeCodeService(liveActivities: center)
    service.handle(try #require(payload("UserPromptSubmit", #","prompt":"Fix the notch""#)))
    #expect(service.sessions.first?.title == "Fix the notch")
    #expect(service.sessions.first?.step == AgentStep.thinking)
    #expect(center.contains("claude.working"))
    service.handle(
      try #require(
        payload("PreToolUse", #","tool_name":"Read","tool_input":{"file_path":"/repo/A.swift"}"#)))
    #expect(service.sessions.first?.step?.contains("A.swift") == true)
    service.handle(try #require(payload("Stop", #","last_assistant_message":"All done.""#)))
    #expect(service.sessions.first?.state == .done)
    #expect(service.sessions.first?.detail == "All done.")
    #expect(!center.contains("claude.working"))
    #expect(center.current?.banner != nil)
  }
}

struct CodexHookInstallerTests {
  @Test func installsCodexHooksOnItsOwnRoute() throws {
    let socket = "/Users/example/Library/Application Support/Cumba/hook.sock"
    let installed = HookInstaller.installing(
      socketPath: socket, token: "t", into: [:], agent: .codex)
    let hooks = try #require(installed["hooks"] as? [String: Any])
    #expect(hooks.keys.sorted() == HookInstaller.codexEvents.map(\.name).sorted())
    #expect(
      HookInstaller.status(of: installed, socketPath: socket, token: "t", agent: .codex)
        == .installed)
    // Claude's and Codex's hooks never count as each other's.
    #expect(
      HookInstaller.status(of: installed, socketPath: socket, token: "t", agent: .claude)
        == .notInstalled)
    let command = HookInstaller.command(socketPath: socket, token: "t", timeout: 5, agent: .codex)
    #expect(command.contains("/codex/hook"))
    #expect(!HookInstaller.isOurs(["type": "command", "command": command], agent: .claude))
    #expect(HookInstaller.removingOurs(from: installed, agent: .codex)["hooks"] == nil)
  }
}

@MainActor
struct CodexSessionTests {
  @Test func sessionsRememberTheirAgent() throws {
    let service = ClaudeCodeService(liveActivities: LiveActivityCenter())
    let payload = try #require(
      HookPayload.decode(
        Data(#"{"session_id":"c1","hook_event_name":"UserPromptSubmit","cwd":"/r/app"}"#.utf8)))
    service.handle(payload, agent: .codex)
    #expect(service.sessions.first?.agent == .codex)
  }
}
