#if canImport(UIKit) && !targetEnvironment(macCatalyst)
import UIKit

/// Applies interruptible, velocity-driven UIKit springs to a floating view supplied by its owner.
/// The owner retains drag state, chooses the resting position, and installs any window or gestures.
@MainActor
final class FloatingViewAnimator {

  private let view: UIView
  private var animator: UIViewPropertyAnimator?

  init(view: UIView) {
    self.view = view
  }

  /// Freezes the displayed frame before a drag, layout change, or presentation takes ownership.
  func stop() {
    guard let animator, case .active = animator.state else {
      self.animator = nil
      return
    }
    let frame = view.layer.presentation()?.frame ?? view.frame
    animator.stopAnimation(true)
    self.animator = nil
    UIView.performWithoutAnimation {
      view.frame = frame
    }
  }

  /// Continues a release with the shared FluidPiP-style settling spring.
  func settle(at position: CGPoint, velocity: CGPoint) {
    animate(to: position, velocity: velocity, duration: 0.8, dampingRatio: 0.8)
  }

  /// Moves a resting view after its available layout changes, without release momentum.
  func relayout(to position: CGPoint) {
    animate(to: position, velocity: .zero, duration: 0.6, dampingRatio: 1)
  }

  private func animate(
    to position: CGPoint,
    velocity: CGPoint,
    duration: TimeInterval,
    dampingRatio: CGFloat
  ) {
    stop()
    guard view.center != position else { return }

    let animator: UIViewPropertyAnimator
    if UIAccessibility.isReduceMotionEnabled {
      animator = .init(duration: 0.25, dampingRatio: 1)
    } else {
      // FluidPictureInPictureController normalizes release velocity by the remaining travel.
      // https://github.com/FluidGroup/FluidInterfaceKit/blob/d5e5aedee1f0ffcfedf10d8417e89ddfbed32f38/Sources/FluidPictureInPicture/FluidPictureInPictureController.swift
      let timing = UISpringTimingParameters(
        dampingRatio: dampingRatio,
        initialVelocity: Self.relativeVelocity(velocity, from: view.center, to: position)
      )
      animator = .init(duration: duration, timingParameters: timing)
    }
    animator.isUserInteractionEnabled = true
    animator.isManualHitTestingEnabled = true
    animator.addAnimations { [view] in
      view.center = position
    }
    self.animator = animator
    animator.startAnimation()
  }

  /// Projects the release by 0.2 seconds; the caller applies its own bounds and docking policy.
  nonisolated static func projectedPosition(from position: CGPoint, velocity: CGPoint) -> CGPoint {
    .init(x: position.x + velocity.x * 0.2, y: position.y + velocity.y * 0.2)
  }

  /// UIKit measures initial spring velocity in remaining travel per second, separately for each axis.
  static func relativeVelocity(_ velocity: CGPoint, from: CGPoint, to: CGPoint) -> CGVector {
    func component(_ speed: CGFloat, distance: CGFloat) -> CGFloat {
      guard abs(distance) > 0.001 else { return 0 }
      let relative = speed / distance
      guard relative.isFinite else { return 0 }
      return relative
    }
    return .init(
      dx: component(velocity.x, distance: to.x - from.x),
      dy: component(velocity.y, distance: to.y - from.y)
    )
  }
}
#endif
