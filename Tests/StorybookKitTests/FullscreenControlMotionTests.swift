import CoreGraphics
import Testing

@testable import StorybookKit

@Suite("Fullscreen control motion")
struct FullscreenControlMotionTests {

  private let bounds = CGRect(x: 32, y: 90, width: 338, height: 720)

  @Test("Release velocity projects the edge and landing position")
  func projectedReleaseSelectsEdge() {
    let target = FullscreenControlMotion.snapTarget(
      from: CGPoint(x: 180, y: 360),
      velocity: CGPoint(x: 800, y: 300),
      centerBounds: bounds
    )

    #expect(target == CGPoint(x: bounds.maxX, y: 420))
  }

  @Test("Projection stays inside safe-area center bounds")
  func projectionClampsToSafeAreaBounds() {
    let target = FullscreenControlMotion.snapTarget(
      from: CGPoint(x: 100, y: 150),
      velocity: CGPoint(x: -1_000, y: -1_000),
      centerBounds: bounds
    )

    #expect(target == CGPoint(x: bounds.minX, y: bounds.minY))
  }

  @Test("Zero-distance axes produce finite spring velocity")
  func normalizedVelocityHandlesZeroDistance() {
    #expect(FullscreenControlMotion.normalizedInitialVelocity(velocity: 700, distance: 0) == 0)
    #expect(FullscreenControlMotion.normalizedInitialVelocity(velocity: 180, distance: 90) == 2)
    #expect(FullscreenControlMotion.normalizedInitialVelocity(velocity: .infinity, distance: 2) == 0)
  }

  @Test("Cancellation settles from position instead of release momentum")
  func cancellationIgnoresReleaseMomentum() {
    let target = FullscreenControlMotion.snapTarget(
      from: CGPoint(x: 100, y: 360),
      velocity: CGPoint(x: 1_200, y: 500),
      centerBounds: bounds,
      cancelled: true
    )

    #expect(target == CGPoint(x: bounds.minX, y: 360))
  }

  @Test("Safe-area and keyboard insets constrain the control center")
  func centerBoundsRespectInsetsAndKeyboard() {
    let centerBounds = FullscreenControlMotion.centerBounds(
      in: CGRect(x: 0, y: 0, width: 402, height: 874),
      safeAreaInsets: .init(top: 62, left: 0, bottom: 34, right: 0),
      controlSize: CGSize(width: 56, height: 56),
      margin: 12,
      keyboardTop: 500
    )

    #expect(centerBounds.minX == 40)
    #expect(centerBounds.maxX == 362)
    #expect(centerBounds.minY == 102)
    #expect(centerBounds.maxY == 460)
  }
}
