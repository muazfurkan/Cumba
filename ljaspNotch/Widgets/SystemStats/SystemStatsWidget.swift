import Observation
import SwiftUI

/// CPU and memory load with a small CPU graph. Samples once a second, and only while the
/// widget is on screen (polling at most every second, only while visible).
@MainActor
@Observable
final class SystemStatsWidget: NotchWidget {
  static let kind = "system-stats"
  static var title: String { String(localized: "System", comment: "Widget name") }
  static let symbol = "cpu"
  static let size = WidgetSize.regular
  static var summary: String {
    String(localized: "CPU and memory use", comment: "Widget description")
  }

  static let historyLength = 30

  private(set) var cpuHistory: [Double] = []
  private(set) var memory: SystemSampler.Memory?

  @ObservationIgnored private var samplingTask: Task<Void, Never>?

  required init(context: WidgetContext) {}

  func makeView() -> AnyView {
    AnyView(SystemStatsView(widget: self))
  }

  func activate() {
    samplingTask?.cancel()
    samplingTask = Task { [weak self] in
      var previous = await Task.detached { SystemSampler.readCPUTicks() }.value
      while !Task.isCancelled {
        do {
          try await Task.sleep(for: .seconds(1))
        } catch {
          return
        }
        let (ticks, memory) = await Task.detached {
          (SystemSampler.readCPUTicks(), SystemSampler.readMemory())
        }.value
        guard let self else { return }
        if let previous, let ticks {
          self.record(SystemSampler.cpuLoad(from: previous, to: ticks))
        }
        self.memory = memory
        previous = ticks
      }
    }
  }

  func deactivate() {
    samplingTask?.cancel()
    samplingTask = nil
  }

  func shutdown() {
    deactivate()
  }

  private func record(_ load: Double) {
    cpuHistory.append(load)
    if cpuHistory.count > Self.historyLength {
      cpuHistory.removeFirst(cpuHistory.count - Self.historyLength)
    }
  }
}

private struct SystemStatsView: View {
  let widget: SystemStatsWidget

  var body: some View {
    WidgetCard {
      VStack(alignment: .leading, spacing: 6) {
        Label("System", systemImage: "cpu")
          .font(.caption)
          .foregroundStyle(.secondary)
        HStack(alignment: .firstTextBaseline) {
          stat(
            title: Text("CPU"), value: widget.cpuHistory.last ?? 0)
          Spacer()
          stat(title: Text("Memory"), value: widget.memory?.fraction ?? 0)
        }
        LoadGraph(values: widget.cpuHistory, capacity: SystemStatsWidget.historyLength)
          .frame(maxHeight: .infinity)
          .accessibilityHidden(true)
      }
    }
  }

  private func stat(title: Text, value: Double) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      title
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(value, format: .percent.precision(.fractionLength(0)))
        .font(.system(size: 18, weight: .semibold).monospacedDigit())
        .contentTransition(.numericText())
    }
    .accessibilityElement(children: .combine)
  }
}

/// Filled line graph of values between 0 and 1, newest on the right.
private struct LoadGraph: View {
  let values: [Double]
  let capacity: Int

  var body: some View {
    GeometryReader { proxy in
      let step = proxy.size.width / CGFloat(max(capacity - 1, 1))
      let offset = CGFloat(capacity - values.count) * step
      let points = values.enumerated().map { index, value in
        CGPoint(
          x: offset + CGFloat(index) * step,
          y: proxy.size.height * (1 - CGFloat(min(max(value, 0), 1))))
      }
      ZStack {
        Path { path in
          guard let first = points.first, let last = points.last else { return }
          path.move(to: CGPoint(x: first.x, y: proxy.size.height))
          for point in points {
            path.addLine(to: point)
          }
          path.addLine(to: CGPoint(x: last.x, y: proxy.size.height))
          path.closeSubpath()
        }
        .fill(.tint.opacity(0.25))
        Path { path in
          path.addLines(points)
        }
        .stroke(.tint, lineWidth: 1.5)
      }
    }
  }
}
