import ActivityIntents
import SwiftUI
import WidgetKit

@main
struct ActivityWidgetBundle: WidgetBundle {
  init() {
    IntentDependencies.bootstrap()
  }

  var body: some Widget {
    // Phase 2 spike widgets — replaced by real complications in Phase 3.
    SpikeToggleComplication()
    SpikeOpenAppComplication()
  }
}
