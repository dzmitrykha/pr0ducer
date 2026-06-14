import Shared
import SwiftUI

public struct ActivityIntervalCardView: View {
  private let interval: DayActivityInterval
  private let calendar: Calendar

  public init(interval: DayActivityInterval, calendar: Calendar) {
    self.interval = interval
    self.calendar = calendar
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(timeRangeText)
          .font(.headline)
          .monospacedDigit()

        Spacer(minLength: 0)

        if interval.isInProgress {
          Text(L10n.dayDetailInProgress)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.accentColor)
        }
      }

      Text(durationText)
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
  }

  private var timeRangeText: String {
    let start = Self.timeFormatter(calendar: calendar).string(from: interval.start)
    let end = interval.isInProgress
      ? L10n.dayDetailNow
      : Self.timeFormatter(calendar: calendar).string(from: interval.end)
    return "\(start) – \(end)"
  }

  private var durationText: String {
    L10n.dayDetailDuration(minutes: durationMinutes)
  }

  private var durationMinutes: Int {
    max(Int(interval.duration / 60), interval.isInProgress ? 0 : 1)
  }

  private var accessibilityLabel: String {
    L10n.dayDetailIntervalAccessibility(
      start: Self.timeFormatter(calendar: calendar).string(from: interval.start),
      end: interval.isInProgress
        ? L10n.dayDetailNow
        : Self.timeFormatter(calendar: calendar).string(from: interval.end),
      minutes: durationMinutes,
      isInProgress: interval.isInProgress
    )
  }

  private static func timeFormatter(calendar: Calendar) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.setLocalizedDateFormatFromTemplate("jm")
    return formatter
  }
}
