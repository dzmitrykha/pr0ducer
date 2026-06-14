/// Widget and complication read model — lives in `Shared` so `Database` and
/// `ActivityWidgetUI` can both use it without a circular dependency.
public struct WidgetSnapshot: Equatable, Sendable {
  public var isActive: Bool
  public var todayCount: Int

  public init(isActive: Bool, todayCount: Int) {
    self.isActive = isActive
    self.todayCount = todayCount
  }
}
