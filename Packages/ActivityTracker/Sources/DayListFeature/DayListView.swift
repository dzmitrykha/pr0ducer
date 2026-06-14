import ComposableArchitecture
import Dependencies
import SwiftUI

public struct DayListView: View {
  let store: StoreOf<DayListFeature>

  @Dependency(\.calendar) private var calendar

  public init(store: StoreOf<DayListFeature>) {
    self.store = store
  }

  public var body: some View {
    Group {
      if store.cards.isEmpty, store.isLoading {
        ProgressView()
      } else {
        ScrollView {
          LazyVStack(spacing: 10) {
            ForEach(store.cards) { card in
              Button {
                store.send(.dayCardTapped(card))
              } label: {
                DayCardView(
                  card: card,
                  calendar: calendar,
                  referenceDate: store.referenceDate
                )
              }
              .buttonStyle(.plain)
              .padding(.vertical, 6)
              .padding(.horizontal, 6)
              .background(cardBackground, in: RoundedRectangle(cornerRadius: 10))
              .onAppear {
                if card.id == store.cards.last?.id, !store.isLoading {
                  store.send(.loadOlderDays)
                }
              }
            }

            if store.isLoading {
              ProgressView()
                .frame(maxWidth: .infinity)
            }
          }
          .padding(.horizontal, 2)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var cardBackground: some ShapeStyle {
    Color.secondary.opacity(0.15)
  }
}
