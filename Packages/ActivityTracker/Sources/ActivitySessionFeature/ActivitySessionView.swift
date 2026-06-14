import ComposableArchitecture
import Shared
import SwiftUI

public struct ActivitySessionView: View {
  let store: StoreOf<ActivitySessionFeature>

  public init(store: StoreOf<ActivitySessionFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: 12) {
      Text(title)
        .font(.headline)
        .multilineTextAlignment(.center)

      Text("\(store.remaining)")
        .font(.system(size: 44, weight: .bold, design: .rounded))
        .monospacedDigit()
        .contentTransition(.numericText())
        .accessibilityHidden(true)

      Text(message)
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      Button(L10n.sessionCancel) {
        store.send(.cancelTapped)
      }
      .buttonStyle(.bordered)
      .tint(.secondary)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      L10n.sessionCountdownAccessibility(actionTitle: title, seconds: store.remaining)
    )
    .onAppear {
      store.send(.onAppear)
    }
  }

  private var title: String {
    switch store.pendingAction {
    case .start:
      L10n.sessionStartTitle
    case .stop:
      L10n.sessionStopTitle
    }
  }

  private var message: String {
    switch store.pendingAction {
    case .start:
      L10n.sessionStartMessage(seconds: store.remaining)
    case .stop:
      L10n.sessionStopMessage(seconds: store.remaining)
    }
  }
}
