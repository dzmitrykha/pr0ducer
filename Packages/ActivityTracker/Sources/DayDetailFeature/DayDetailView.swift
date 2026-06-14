import ComposableArchitecture
import Dependencies
import Shared
import SwiftUI

public struct DayDetailView: View {
  let store: StoreOf<DayDetailFeature>

  @Dependency(\.calendar) private var calendar

  public init(store: StoreOf<DayDetailFeature>) {
    self.store = store
  }

  public var body: some View {
    Group {
      if store.intervals.isEmpty, store.isLoading {
        ProgressView()
      } else if store.intervals.isEmpty {
        EmptyDayDetailView()
      } else {
        List {
          ForEach(store.intervals) { interval in
            ActivityIntervalCardView(interval: interval, calendar: calendar)
              .listRowInsets(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
              .listRowBackground(Color.clear)
              .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                  store.send(.delete(interval.id))
                } label: {
                  Label(L10n.dayDetailDelete, systemImage: "trash")
                }
              }
          }
        }
        .listStyle(.plain)
      }
    }
    .navigationTitle(dayTitle)
    #if os(watchOS) || os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .onAppear {
      store.send(.onAppear)
    }
  }

  private var dayTitle: String {
    if calendar.isDate(store.dayStart, inSameDayAs: store.referenceDate) {
      return L10n.dayTitleToday
    }
    if
      let yesterday = calendar.date(
        byAdding: .day,
        value: -1,
        to: calendar.startOfDay(for: store.referenceDate)
      ),
      calendar.isDate(store.dayStart, inSameDayAs: yesterday)
    {
      return L10n.dayTitleYesterday
    }
    return Self.shortDateFormatter(calendar: calendar).string(from: store.dayStart)
  }

  private static func shortDateFormatter(calendar: Calendar) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.setLocalizedDateFormatFromTemplate("MMMd")
    return formatter
  }
}

private struct EmptyDayDetailView: View {
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "clock")
        .font(.system(size: 28))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text(L10n.dayDetailEmptyTitle)
        .font(.headline)
        .multilineTextAlignment(.center)

      Text(L10n.dayDetailEmptyMessage)
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(.horizontal, 8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(L10n.dayDetailEmptyTitle). \(L10n.dayDetailEmptyMessage)")
  }
}
