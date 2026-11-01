import SwiftUI

/// The open tab's widgets as a page, like the iPhone's Home Screen: a two-finger swipe drags
/// it aside while the next tab's page comes in beside it, and the page being left fades and
/// shrinks a little as the other comes forward. Clicking a tab slides the pages the same way.
/// With Reduce Motion the pages cross-fade instead.
struct TabPager: View {
  let host: WidgetHost
  let secondary: Color
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Space between pages, the panel's side margin, so a page off to the side starts right at
  /// the panel's edge.
  private static let gap: CGFloat = 28

  private struct Page: Identifiable {
    let tab: WidgetLayout.Tab
    let position: CGFloat
    var id: String { tab.id }
  }

  var body: some View {
    if reduceMotion {
      WidgetRow(host: host, tab: host.selectedTab, secondary: secondary)
        .id(host.selectedTab?.id)
        .transition(.opacity)
    } else {
      GeometryReader { proxy in
        let width = proxy.size.width
        let span = width + Self.gap
        ZStack {
          ForEach(pages(span: span)) { page in
            let distance = min(abs(page.position) / max(span, 1), 1)
            WidgetRow(host: host, tab: page.tab, secondary: secondary)
              .frame(width: width, height: proxy.size.height)
              .scaleEffect(1 - distance * 0.06)
              .opacity(1 - distance * 0.75)
              .offset(x: page.position)
              // A tab opened by a click comes in from the side the pages move toward.
              .transition(
                .offset(x: CGFloat(host.pageDirection) * span).combined(with: .opacity)
              )
              .allowsHitTesting(page.id == host.selectedTab?.id)
          }
        }
      }
    }
  }

  /// The page leaving, the open one and the one a swipe is revealing, left to right.
  private func pages(span: CGFloat) -> [Page] {
    guard let selected = host.selectedTab else { return [] }
    var pages: [Page] = []
    if let leaving = host.leavingPage, leaving.tabID != selected.id,
      let tab = host.tabs.first(where: { $0.id == leaving.tabID })
    {
      pages.append(Page(tab: tab, position: leaving.side * span))
    }
    pages.append(Page(tab: selected, position: host.pageDrag))
    if let neighbor = host.swipeNeighbor, !pages.contains(where: { $0.id == neighbor.id }) {
      let side: CGFloat = host.pageDrag < 0 ? 1 : -1
      pages.append(Page(tab: neighbor, position: side * span + host.pageDrag))
    }
    return pages
  }
}
