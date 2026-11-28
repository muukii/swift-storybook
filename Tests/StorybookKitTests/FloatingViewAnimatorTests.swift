#if canImport(UIKit) && !targetEnvironment(macCatalyst)
import Testing
import UIKit

@testable import StorybookKit

@MainActor
@Suite("Floating view animation")
struct FloatingViewAnimatorTests {

  private let bounds = CGRect(x: 32, y: 90, width: 338, height: 720)

  @Test("Release velocity projects the edge and landing position")
  func projectedReleaseSelectsEdge() {
    let projected = FloatingViewAnimator.projectedPosition(
      from: CGPoint(x: 180, y: 360),
      velocity: CGPoint(x: 800, y: 300)
    )
    let target = FullscreenControlMotion.snapTarget(
      projectedPosition: projected,
      centerBounds: bounds
    )

    #expect(target == CGPoint(x: bounds.maxX, y: 420))
  }

  @Test("Zero-distance axes produce finite spring velocity")
  func relativeVelocityHandlesZeroDistance() {
    let relative = FloatingViewAnimator.relativeVelocity(
      CGPoint(x: 700, y: 180),
      from: .zero,
      to: CGPoint(x: 0, y: 90)
    )
    #expect(relative == CGVector(dx: 0, dy: 2))

    let nonFinite = FloatingViewAnimator.relativeVelocity(
      CGPoint(x: CGFloat.infinity, y: 0),
      from: .zero,
      to: CGPoint(x: 2, y: 0)
    )
    #expect(nonFinite == .zero)
  }

  @Test("Settling without release momentum docks from the current position")
  func zeroVelocityPreservesLandingHeight() {
    let projected = FloatingViewAnimator.projectedPosition(
      from: CGPoint(x: 100, y: 360),
      velocity: .zero
    )
    let target = FullscreenControlMotion.snapTarget(
      projectedPosition: projected,
      centerBounds: bounds
    )

    #expect(target == CGPoint(x: bounds.minX, y: 360))
  }
}
#endif
