#if canImport(WidgetKit)
import WidgetKit
#endif

/// Reloads widget timelines after cross-process database writes.
public enum WidgetSync {
  public static func reloadAllTimelines() {
    #if canImport(WidgetKit)
    WidgetCenter.shared.reloadAllTimelines()
    #endif
  }
}
