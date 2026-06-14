import Shared
import SwiftUI

/// Circular activity ring with today's count — shared by complications and the app.
public struct ActivityRingView: View {
  private let snapshot: WidgetSnapshot

  public init(snapshot: WidgetSnapshot) {
    self.snapshot = snapshot
  }

  public var body: some View {
    ZStack {
      if snapshot.isActive {
        Circle()
          .fill(Color.accentColor)
      } else {
        Circle()
          .strokeBorder(Color.accentColor, lineWidth: 2)
      }

      Text(snapshot.countDisplayText)
        .font(.system(size: 20, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(snapshot.isActive ? Color.black : Color.primary)
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
