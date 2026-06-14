/// Widget and complication read model — lives in `Shared` so `Database` and
/// `ActivityWidgetUI` can both use it without a circular dependency.
public struct WidgetSnapshot: Equatable, Sendable {
  public var isActive: Bool
  public var todayCount: Int

  public init(isActive: Bool, todayCount: Int) {
    self.isActive = isActive
    self.todayCount = todayCount
  }

  /// Formats today's count for the small complication surface (caps at 99+).
  public var countDisplayText: String {
    Self.countDisplayText(for: todayCount)
  }

  public static func countDisplayText(for count: Int) -> String {
    count > 99 ? "99+" : "\(count)"
  }
}
