import Shared
import SwiftUI

/// Read-only complication that opens the app — visually distinct from the toggle ring.
public struct OpenAppRingView: View {
  private let snapshot: WidgetSnapshot

  public init(snapshot: WidgetSnapshot) {
    self.snapshot = snapshot
  }

  public var body: some View {
    ZStack {
      Circle()
        .strokeBorder(
          .foreground,
          style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])
        )
        .widgetAccentable()

      VStack(spacing: 1) {
        Text(snapshot.countDisplayText)
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.primary)
          .minimumScaleFactor(0.5)
          .lineLimit(1)

        Image(systemName: "list.bullet")
          .font(.system(size: 14, weight: .semibold))
          .widgetAccentable()
      }
    }
    .padding(2)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(L10n.openRingAccessibility(count: snapshot.todayCount))
  }
}
