import ActivitySessionFeature
import ComposableArchitecture
import DayDetailFeature
import DayListFeature
import SwiftUI

public struct AppView: View {
  let store: StoreOf<AppFeature>

  public init(store: StoreOf<AppFeature>) {
    self.store = store
  }

  public var body: some View {
    NavigationStack {
      DayListView(
        store: store.scope(state: \.dayList, action: \.dayList)
      )
      .navigationDestination(item: dayDetailBinding) { _ in
        if let detailStore = store.scope(state: \.dayDetail, action: \.dayDetail) {
          DayDetailView(store: detailStore)
        }
      }
    }
    .sheet(
      isPresented: Binding(
        get: { store.session != nil },
        set: { isPresented in
          if !isPresented {
            store.send(.session(.dismiss))
          }
        }
      )
    ) {
      if let sessionStore = store.scope(state: \.session, action: \.session.presented) {
        ActivitySessionView(store: sessionStore)
      }
    }
    .onAppear {
      store.send(.onAppear)
    }
  }

  private var dayDetailBinding: Binding<DayDetailFeature.State?> {
    Binding(
      get: { store.dayDetail },
      set: { newValue in
        if newValue == nil {
          store.send(.dayDetailDismissed)
        }
      }
    )
  }
}
