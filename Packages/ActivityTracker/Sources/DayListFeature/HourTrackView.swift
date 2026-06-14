import SwiftUI

/// Horizontal 0–24 hour track with proportional activity segments.
public struct HourTrackView: View {
  private let segments: [ActivitySegment]

  public init(segments: [ActivitySegment]) {
    self.segments = segments
  }

  public var body: some View {
    VStack(spacing: 2) {
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 2)
            .fill(Color.secondary.opacity(0.2))

          ForEach(segments) { segment in
            SegmentBar(segment: segment, trackWidth: geometry.size.width)
          }
        }
      }
      .frame(height: 12)

      HStack(spacing: 0) {
        axisLabel("0")
        Spacer(minLength: 0)
        axisLabel("12")
        Spacer(minLength: 0)
        axisLabel("24")
      }
      .frame(maxWidth: .infinity)
    }
  }

  private func axisLabel(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 8, weight: .medium, design: .rounded))
      .foregroundStyle(.secondary)
      .monospacedDigit()
  }
}

private struct SegmentBar: View {
  let segment: ActivitySegment
  let trackWidth: CGFloat

  @State private var pulse = false

  var body: some View {
    let width = max((segment.end - segment.start) * trackWidth, 2)
    let offset = segment.start * trackWidth

    RoundedRectangle(cornerRadius: 2)
      .fill(segment.isInProgress ? Color.accentColor.opacity(0.55) : Color.accentColor)
      .frame(width: width)
      .offset(x: offset)
      .opacity(segment.isInProgress ? (pulse ? 1 : 0.65) : 1)
      .task(id: segment.isInProgress) {
        guard segment.isInProgress else { return }
        while !Task.isCancelled {
          withAnimation(.easeInOut(duration: 1)) {
            pulse.toggle()
          }
          try? await Task.sleep(for: .seconds(1))
        }
      }
  }
}
