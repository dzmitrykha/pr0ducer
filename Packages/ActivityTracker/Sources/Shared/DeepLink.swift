import Foundation

/// Parsed deep-link routes for `activitytracker://` URLs.
public enum DeepLink: Equatable, Sendable {
  case open

  public init?(url: URL) {
    guard url.scheme?.lowercased() == "activitytracker" else { return nil }
    let route = (url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
      .lowercased()
    switch route {
    case "open":
      self = .open
    default:
      return nil
    }
  }

  public var url: URL {
    switch self {
    case .open:
      URL(string: "activitytracker://open")!
    }
  }
}
