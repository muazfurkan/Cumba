import SwiftUI

/// Installs or removes the Claude Code hooks in ~/.claude/settings.json. Every change is
/// shown as a diff and needs a confirmation; the old file is backed up first.
struct ClaudeCodeSettingsView: View {
  let server: LocalServer
  @Bindable var settings: AppSettings

  @State private var status: HookInstaller.Status?
  @State private var hooksDisabled = false
  @State private var plan: HookInstaller.Plan?
  @State private var message: String?

  private let installer = HookInstaller.standard

  var body: some View {
    Form {
      Section("Hooks") {
        LabeledContent("Status") { statusLabel }
        LabeledContent("Socket") { socketLabel }
        if hooksDisabled {
          Label(
            "disableAllHooks is on in settings.json, so Claude Code ignores every hook.",
            systemImage: "exclamationmark.triangle.fill"
          )
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
        }
        HStack {
          Button(status == .outdated ? "Update…" : "Install…") { review(install: true) }
            .disabled(server.hookToken.isEmpty || status == .installed)
          Button("Remove…", role: .destructive) { review(install: false) }
            .disabled(status == .notInstalled || status == nil)
        }
        if let message {
          Text(message)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Section("In the Notch") {
        Picker("Allow from the notch", selection: $settings.notchApprovals) {
          Text("All requests").tag(NotchApprovals.all)
          Text("All except shell commands").tag(NotchApprovals.exceptShell)
          Text("Never (only Deny and In Terminal)").tag(NotchApprovals.never)
        }
        Text(
          "Allow in the notch is the same as Allow in Claude Code: the tool runs right away. Requests with hidden characters never get an Allow button."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }
      Section {
        Text(
          "Hooks send events from Claude Code in the terminal, IDE extensions and the Claude desktop app to ljaspNotch through a private socket that only your user account can open. Permission requests then appear in the notch. When ljaspNotch isn't running, Claude Code carries on as usual. Session data stays in memory."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        HStack {
          Link(
            "Set up by hand",
            destination: URL(
              string: "https://github.com/muazfurkan/ljaspNotch/blob/main/docs/claude-code-setup.md"
            ) ?? URL(filePath: "/"))
          Spacer()
          Button("Copy Hook Token") { SecretCopy.copy(server.hookToken) }
            .disabled(server.hookToken.isEmpty)
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 520, height: 540)
    .task { await refresh() }
    .sheet(item: $plan) { plan in
      DiffSheet(plan: plan) {
        self.plan = nil
        apply(plan)
      } cancel: {
        self.plan = nil
      }
    }
  }

  @ViewBuilder private var statusLabel: some View {
    switch status {
    case .installed:
      Label("Installed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
    case .outdated:
      Label("Out of date (token or format changed)", systemImage: "arrow.triangle.2.circlepath")
        .foregroundStyle(.orange)
    case .notInstalled:
      Text("Not installed").foregroundStyle(.secondary)
    case nil:
      Text(verbatim: "—").foregroundStyle(.secondary)
    }
  }

  @ViewBuilder private var socketLabel: some View {
    switch server.hookStatus {
    case .running:
      Label("Listening", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
    case .stopped:
      Text("Stopped").foregroundStyle(.secondary)
    case .failed(let message):
      Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
    }
  }

  private func refresh() async {
    let installer = installer
    let token = server.hookToken
    let result = await Task.detached { () -> (HookInstaller.Status?, Bool) in
      let status = try? installer.status(token: token)
      let disabled = (try? installer.hooksAreDisabled()) ?? false
      return (status, disabled)
    }.value
    status = result.0
    hooksDisabled = result.1
    // The socket runs only while hooks are installed.
    switch result.0 {
    case .notInstalled: server.stopHookServer()
    case .installed, .outdated: server.startHookServer()
    case nil: break
    }
    if result.0 == nil {
      message = String(
        localized: "~/.claude/settings.json isn't valid JSON. Fix it first; nothing was changed.")
    }
  }

  private func review(install: Bool) {
    let installer = installer
    let token = server.hookToken
    Task {
      let result = await Task.detached { () -> Result<HookInstaller.Plan, HookInstaller.Failure> in
        do throws(HookInstaller.Failure) {
          return .success(
            try install ? installer.planInstall(token: token) : installer.planUninstall())
        } catch {
          return .failure(error)
        }
      }.value
      switch result {
      case .success(let reviewed): plan = reviewed
      case .failure(let failure): message = describe(failure)
      }
    }
  }

  private func apply(_ plan: HookInstaller.Plan) {
    let installer = installer
    Task {
      let result = await Task.detached { () -> Result<URL?, HookInstaller.Failure> in
        do throws(HookInstaller.Failure) {
          return .success(try installer.apply(plan))
        } catch {
          return .failure(error)
        }
      }.value
      switch result {
      case .success(let backup):
        message =
          backup.map {
            String(localized: "Saved. The previous file was backed up to \($0.lastPathComponent).")
          } ?? String(localized: "Saved.")
      case .failure(let failure):
        message = describe(failure)
      }
      await refresh()
    }
  }

  private func describe(_ failure: HookInstaller.Failure) -> String {
    switch failure {
    case .unreadable:
      String(
        localized: "~/.claude/settings.json isn't valid JSON. Fix it first; nothing was changed.")
    case .changedSinceReview:
      String(
        localized:
          "settings.json changed while you were reviewing it. Nothing was written; please review again."
      )
    case .writeFailed(let reason):
      String(localized: "Couldn't write settings.json: \(reason)")
    }
  }
}

extension HookInstaller.Plan: Identifiable {
  var id: String { newText }
}

/// Shows the planned change line by line before anything is written.
private struct DiffSheet: View {
  let plan: HookInstaller.Plan
  let confirm: () -> Void
  let cancel: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Review changes to ~/.claude/settings.json")
        .font(.headline)
      Text("A backup of the current file is made before saving.")
        .font(.callout)
        .foregroundStyle(.secondary)
      if plan.reformats {
        Label(
          "Saving also rewrites the file in a standard format (keys sorted, two-space indents). Its contents change only as shown below.",
          systemImage: "info.circle"
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(plan.diff) { line in
            Text(prefix(line.kind) + line.text)
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(color(line.kind))
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(background(line.kind))
          }
        }
        .textSelection(.enabled)
        .padding(8)
      }
      .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
      HStack {
        Spacer()
        Button("Cancel", role: .cancel, action: cancel)
          .keyboardShortcut(.cancelAction)
        Button("Save", action: confirm)
          .keyboardShortcut(.defaultAction)
          .disabled(!plan.hasChanges)
      }
    }
    .padding(20)
    .frame(width: 600, height: 460)
  }

  private func prefix(_ kind: DiffLine.Kind) -> String {
    switch kind {
    case .added: "+ "
    case .removed: "- "
    case .context: "  "
    }
  }

  private func color(_ kind: DiffLine.Kind) -> Color {
    switch kind {
    case .added: .green
    case .removed: .red
    case .context: .primary
    }
  }

  private func background(_ kind: DiffLine.Kind) -> Color {
    switch kind {
    case .added: .green.opacity(0.08)
    case .removed: .red.opacity(0.08)
    case .context: .clear
    }
  }
}
