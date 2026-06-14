import Dependencies
import DependenciesMacros
import Foundation

/// A route persisted while the app is inactive, resolved on next activation.
public enum PendingAction: String, Equatable, Sendable, Codable {
  case open
  case confirmStart
  case confirmStop
}

extension PendingAction {
  public var deepLink: DeepLink? {
    switch self {
    case .open:
      .open
    case .confirmStart, .confirmStop:
      nil
    }
  }

  public init?(deepLink: DeepLink) {
    switch deepLink {
    case .open:
      self = .open
    }
  }
}

@DependencyClient
public struct PendingActionStore: Sendable {
  public var save: @Sendable (PendingAction) -> Void = { _ in }
  public var consume: @Sendable () -> PendingAction? = { nil }
}

extension PendingActionStore: DependencyKey {
  private static let storageKey = "pendingAction"

  public static let liveValue: PendingActionStore = {
    let suiteName = AppGroup.identifier
    return Self(
      save: { action in
        UserDefaults(suiteName: suiteName)?.set(action.rawValue, forKey: storageKey)
      },
      consume: {
        guard
          let defaults = UserDefaults(suiteName: suiteName),
          let raw = defaults.string(forKey: storageKey),
          let action = PendingAction(rawValue: raw)
        else { return nil }
        defaults.removeObject(forKey: storageKey)
        return action
      }
    )
  }()

  public static let testValue = Self(
    save: { _ in },
    consume: { nil }
  )
}

extension DependencyValues {
  public var pendingActionStore: PendingActionStore {
    get { self[PendingActionStore.self] }
    set { self[PendingActionStore.self] = newValue }
  }
}
