import Foundation

/// Localized user-facing copy backed by `Resources/Localizable.xcstrings`.
public enum L10n {
  public static func toggleRingAccessibilityActive(count: Int) -> String {
    String(format: string("toggle.ring.accessibility.active"), count)
  }

  public static func toggleRingAccessibilityIdle(count: Int) -> String {
    String(format: string("toggle.ring.accessibility.idle"), count)
  }

  public static func openRingAccessibility(count: Int) -> String {
    String(format: string("open.ring.accessibility"), count)
  }

  public static var dayTitleToday: String { string("day.title.today") }
  public static var dayTitleYesterday: String { string("day.title.yesterday") }

  public static func dayAccessibilityLabel(
    dayTitle: String,
    count: Int,
    segmentCount: Int
  ) -> String {
    String(
      format: string("day.accessibility.label"),
      dayTitle,
      count,
      segmentCount
    )
  }

  public static var dayAccessibilityHint: String { string("day.accessibility.hint") }

  public static var dayDetailDelete: String { string("day.detail.delete") }
  public static var dayDetailEmptyTitle: String { string("day.detail.empty.title") }
  public static var dayDetailEmptyMessage: String { string("day.detail.empty.message") }
  public static var dayDetailInProgress: String { string("day.detail.in.progress") }
  public static var dayDetailNow: String { string("day.detail.now") }

  public static func dayDetailDuration(minutes: Int) -> String {
    String(format: string("day.detail.duration"), minutes)
  }

  public static func dayDetailIntervalAccessibility(
    start: String,
    end: String,
    minutes: Int,
    isInProgress: Bool
  ) -> String {
    if isInProgress {
      return String(
        format: string("day.detail.interval.accessibility.in.progress"),
        start,
        minutes
      )
    }
    return String(
      format: string("day.detail.interval.accessibility"),
      start,
      end,
      minutes
    )
  }

  public static func hourTrackAccessibility(segmentCount: Int) -> String {
    String(format: string("hour.track.accessibility"), segmentCount)
  }

  public static var emptyTitle: String { string("empty.title") }
  public static var emptyMessage: String { string("empty.message") }

  public static var sessionStartTitle: String { string("session.start.title") }
  public static var sessionStopTitle: String { string("session.stop.title") }
  public static var sessionCancel: String { string("session.cancel") }

  public static func sessionStartMessage(seconds: Int) -> String {
    String(format: string("session.start.message"), seconds)
  }

  public static func sessionStopMessage(seconds: Int) -> String {
    String(format: string("session.stop.message"), seconds)
  }

  public static func sessionCountdownAccessibility(
    actionTitle: String,
    seconds: Int
  ) -> String {
    String(format: string("session.countdown.accessibility"), actionTitle, seconds)
  }

  public static var widgetToggleDisplayName: String { string("widget.toggle.displayName") }
  public static var widgetToggleDescription: String { string("widget.toggle.description") }
  public static var widgetOpenDisplayName: String { string("widget.open.displayName") }
  public static var widgetOpenDescription: String { string("widget.open.description") }

  private static func string(_ key: String) -> String {
    String(localized: String.LocalizationValue(key), bundle: .module)
  }
}
