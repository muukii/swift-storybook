#if canImport(UIKit) && !targetEnvironment(macCatalyst)
import Testing
import UIKit

@testable import StorybookKit

@MainActor
@Suite("Fullscreen control overlay hit testing")
struct FullscreenControlOverlayTests {

  @Test("Only the control is hit and the overlay window cannot become key")
  func overlayWindowPassesThroughOutsideControl() {
    let window = FullscreenControlOverlayWindow(
      frame: CGRect(x: 0, y: 0, width: 200, height: 300)
    )
    let container = FullscreenControlPassthroughView()
    container.frame = window.bounds

    let control = UIView(frame: CGRect(x: 120, y: 220, width: 56, height: 56))
    let button = UIButton(frame: control.bounds)
    control.addSubview(button)
    container.addSubview(control)
    container.controlView = control

    let rootViewController = UIViewController()
    rootViewController.view = container
    window.rootViewController = rootViewController
    window.isHidden = false
    window.layoutIfNeeded()

    defer {
      window.isHidden = true
      window.rootViewController = nil
    }

    #expect(window.canBecomeKey == false)
    #expect(window.hitTest(CGPoint(x: 20, y: 20), with: nil) == nil)
    #expect(window.hitTest(CGPoint(x: 121, y: 221), with: nil) == nil)
    #expect(window.hitTest(CGPoint(x: 148, y: 248), with: nil) === button)
  }

  @Test("The animating control is hit at its presentation position")
  func overlayHitsControlDuringSnap() throws {
    let window = FullscreenControlOverlayWindow(
      frame: CGRect(x: 0, y: 0, width: 200, height: 300)
    )
    let container = FullscreenControlPassthroughView()
    container.frame = window.bounds

    let control = UIView(frame: CGRect(x: 12, y: 52, width: 56, height: 56))
    let button = UIButton(frame: control.bounds)
    control.addSubview(button)
    container.addSubview(control)
    container.controlView = control

    let rootViewController = UIViewController()
    rootViewController.view = container
    window.rootViewController = rootViewController
    window.isHidden = false
    window.layoutIfNeeded()

    let startFrame = control.frame
    let startTime = control.layer.convertTime(CACurrentMediaTime(), from: nil)
    control.layer.speed = 0
    control.layer.timeOffset = startTime

    let animator = FloatingViewAnimator(view: control)
    animator.settle(at: CGPoint(x: 148, y: 248), velocity: CGPoint(x: 400, y: 600))
    CATransaction.flush()
    control.layer.timeOffset = startTime + 0.1
    CATransaction.flush()

    defer {
      animator.stop()
      window.isHidden = true
      window.rootViewController = nil
    }

    let presentationFrame = try #require(control.layer.presentation()?.frame)
    #expect(presentationFrame != startFrame)
    #expect(presentationFrame != control.frame)
    #expect(
      window.hitTest(
        CGPoint(x: presentationFrame.midX, y: presentationFrame.midY),
        with: nil
      ) === button
    )
    animator.stop()
    #expect(control.frame == presentationFrame)
  }
}
#endif
