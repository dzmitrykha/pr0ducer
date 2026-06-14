import Shared
import Testing

@Test func countDisplayTextFormatsSmallValues() {
  #expect(WidgetSnapshot.countDisplayText(for: 0) == "0")
  #expect(WidgetSnapshot.countDisplayText(for: 1) == "1")
  #expect(WidgetSnapshot.countDisplayText(for: 99) == "99")
}

@Test func countDisplayTextCapsAt99Plus() {
  #expect(WidgetSnapshot.countDisplayText(for: 100) == "99+")
  #expect(WidgetSnapshot.countDisplayText(for: 999) == "99+")
}

@Test func countDisplayTextUsesSnapshotTodayCount() {
  let snapshot = WidgetSnapshot(isActive: true, todayCount: 42)
  #expect(snapshot.countDisplayText == "42")
}
