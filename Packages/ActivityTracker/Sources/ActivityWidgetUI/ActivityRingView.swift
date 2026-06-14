import Shared
import SwiftUI

/// Circular activity ring with today's count — shared by complications and the app.
public struct ActivityRingView: View {
  private enum Layout {
    /// Softens accented ring elements so primary (white) text stays readable.
    static let accentOpacity = 0.45
  }

  private let snapshot: WidgetSnapshot

  public init(snapshot: WidgetSnapshot) {
    self.snapshot = snapshot
  }

  public var body: some View {
    ZStack {
      if snapshot.isActive {
        Circle()
          .fill(.foreground)
          .opacity(Layout.accentOpacity)
          .widgetAccentable()
      } else {
        Circle()
          .strokeBorder(.foreground, lineWidth: 2)
          .opacity(Layout.accentOpacity)
          .widgetAccentable()
      }

      Text(snapshot.countDisplayText)
        .font(.system(size: 20, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.primary)
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }
    .padding(2)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }

  private var accessibilityLabel: String {
    if snapshot.isActive {
      L10n.toggleRingAccessibilityActive(count: snapshot.todayCount)
    } else {
      L10n.toggleRingAccessibilityIdle(count: snapshot.todayCount)
    }
  }
}
