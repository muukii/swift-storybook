#if canImport(UIKit)
import UIKit

#if targetEnvironment(macCatalyst)
@MainActor
final class FullscreenControlSession {

  func activate(window: UIWindow?, onMenuTap: @escaping @MainActor (UIView) -> Void) {}

  func deactivate() {}
}
#else
@MainActor
final class FullscreenControlSession {

  private var overlayWindow: UIWindow?

  func activate(
    window hostWindow: UIWindow?,
    onMenuTap: @escaping @MainActor (UIView) -> Void
  ) {
    guard let hostWindow, let windowScene = hostWindow.windowScene else { return }

    if overlayWindow?.windowScene === windowScene {
      return
    }

    deactivate()

    let overlay = FullscreenControlOverlayWindow(windowScene: windowScene)
    overlay.windowLevel = .init(rawValue: UIWindow.Level.alert.rawValue + 1)
    overlay.backgroundColor = .clear
    overlay.isOpaque = false
    overlay.rootViewController = FullscreenControlOverlayViewController(
      hostWindow: hostWindow,
      onMenuTap: onMenuTap
    )
    overlayWindow = overlay
    overlay.isHidden = false
  }

  func deactivate() {
    overlayWindow?.isHidden = true
    overlayWindow?.rootViewController = nil
    overlayWindow = nil
  }
}

@MainActor
final class FullscreenControlOverlayWindow: UIWindow {

  override var canBecomeKey: Bool { false }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard let hitView = super.hitTest(point, with: event),
      hitView !== self,
      hitView !== rootViewController?.viewIfLoaded
    else {
      return nil
    }

    return hitView
  }
}

@MainActor
private final class FullscreenControlOverlayViewController: UIViewController {

  private static let diameter: CGFloat = 56
  private static let margin: CGFloat = 12

  private weak var hostWindow: UIWindow?
  private let onMenuTap: @MainActor (UIView) -> Void
  private let control = UIVisualEffectView(
    effect: UIBlurEffect(style: .systemThinMaterial)
  )
  private let button = UIButton(type: .system)
  private lazy var animator = FloatingViewAnimator(view: control)
  private var dragOffset = CGPoint.zero
  private var isDragging = false
  private var hasPosition = false
  private var lastBounds: CGRect?
  private var lastSafeAreaInsets = FullscreenControlMotion.Insets(
    top: 0,
    left: 0,
    bottom: 0,
    right: 0
  )
  private var lastKeyboardTop: CGFloat?

  init(
    hostWindow: UIWindow,
    onMenuTap: @escaping @MainActor (UIView) -> Void
  ) {
    self.hostWindow = hostWindow
    self.onMenuTap = onMenuTap
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    let container = FullscreenControlPassthroughView()
    container.backgroundColor = .clear
    container.isOpaque = false
    view = container

    control.bounds.size = CGSize(width: Self.diameter, height: Self.diameter)
    control.layer.cornerRadius = Self.diameter / 2
    control.clipsToBounds = true
    control.isAccessibilityElement = false
    container.addSubview(control)
    container.controlView = control

    button.translatesAutoresizingMaskIntoConstraints = false
    button.setImage(
      UIImage(
        systemName: "ellipsis",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
      ),
      for: .normal
    )
    button.tintColor = .label
    button.accessibilityLabel = "Fullscreen actions"
    button.accessibilityHint = "Drag to move or tap to open fullscreen actions."
    button.accessibilityIdentifier = "storybook.fullscreen.menu"
    button.addTarget(self, action: #selector(menuButtonTapped), for: .touchUpInside)
    control.contentView.addSubview(button)

    NSLayoutConstraint.activate([
      button.leadingAnchor.constraint(equalTo: control.contentView.leadingAnchor),
      button.trailingAnchor.constraint(equalTo: control.contentView.trailingAnchor),
      button.topAnchor.constraint(equalTo: control.contentView.topAnchor),
      button.bottomAnchor.constraint(equalTo: control.contentView.bottomAnchor),
    ])

    let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
    pan.maximumNumberOfTouches = 1
    control.addGestureRecognizer(pan)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    view.isOpaque = false
    view.keyboardLayoutGuide.followsUndockedKeyboard = false
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    let safeAreaInsets = resolvedSafeAreaInsets
    let keyboardTop = visibleKeyboardTop
    guard lastBounds != view.bounds ||
      lastSafeAreaInsets != safeAreaInsets ||
      lastKeyboardTop != keyboardTop
    else {
      return
    }

    lastBounds = view.bounds
    lastSafeAreaInsets = safeAreaInsets
    lastKeyboardTop = keyboardTop

    let bounds = centerBounds(safeAreaInsets: safeAreaInsets, keyboardTop: keyboardTop)
    if hasPosition == false {
      control.center = CGPoint(x: bounds.maxX, y: bounds.maxY)
      hasPosition = true
    } else {
      animator.stop()
      if isDragging {
        control.center = FullscreenControlMotion.clamp(control.center, to: bounds)
      } else {
        let target = FullscreenControlMotion.snapTarget(
          projectedPosition: control.center,
          centerBounds: bounds
        )
        animator.relayout(to: target)
      }
    }
  }

  override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    view.setNeedsLayout()
  }

  @objc private func menuButtonTapped() {
    animator.stop()
    onMenuTap(button)
  }

  @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
    switch gesture.state {
    case .began:
      animator.stop()
      let location = gesture.location(in: view)
      dragOffset = CGPoint(
        x: control.center.x - location.x,
        y: control.center.y - location.y
      )
      isDragging = true
    case .changed:
      let location = gesture.location(in: view)
      let proposed = CGPoint(
        x: location.x + dragOffset.x,
        y: location.y + dragOffset.y
      )
      control.center = FullscreenControlMotion.clamp(
        proposed,
        to: centerBounds(safeAreaInsets: resolvedSafeAreaInsets, keyboardTop: visibleKeyboardTop)
      )
    case .ended:
      isDragging = false
      settle(velocity: gesture.velocity(in: view))
    case .cancelled:
      isDragging = false
      settle(velocity: .zero)
    case .failed, .possible:
      break
    @unknown default:
      break
    }
  }

  private var resolvedSafeAreaInsets: FullscreenControlMotion.Insets {
    let local = view.safeAreaInsets
    let host = hostWindow?.safeAreaInsets ?? .zero
    return .init(
      top: max(local.top, host.top),
      left: max(local.left, host.left),
      bottom: max(local.bottom, host.bottom),
      right: max(local.right, host.right)
    )
  }

  private var visibleKeyboardTop: CGFloat? {
    let frame = view.keyboardLayoutGuide.layoutFrame
    guard frame.height > 0,
      frame.minY < view.bounds.maxY
    else {
      return nil
    }
    return frame.minY
  }

  private func centerBounds(
    safeAreaInsets: FullscreenControlMotion.Insets,
    keyboardTop: CGFloat?
  ) -> CGRect {
    FullscreenControlMotion.centerBounds(
      in: view.bounds,
      safeAreaInsets: safeAreaInsets,
      controlSize: control.bounds.size,
      margin: Self.margin,
      keyboardTop: keyboardTop
    )
  }

  private func settle(velocity: CGPoint) {
    let bounds = centerBounds(safeAreaInsets: resolvedSafeAreaInsets, keyboardTop: visibleKeyboardTop)
    let target = FullscreenControlMotion.snapTarget(
      projectedPosition: FloatingViewAnimator.projectedPosition(from: control.center, velocity: velocity),
      centerBounds: bounds
    )
    animator.settle(at: target, velocity: velocity)
  }
}

@MainActor
final class FullscreenControlPassthroughView: UIView {

  weak var controlView: UIView?

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard let controlView else { return nil }

    let visibleFrame = controlView.layer.presentation()?.frame ?? controlView.frame
    guard visibleFrame.contains(point),
      visibleFrame.width > 0,
      visibleFrame.height > 0
    else {
      return nil
    }

    let normalizedX = (point.x - visibleFrame.midX) / (visibleFrame.width / 2)
    let normalizedY = (point.y - visibleFrame.midY) / (visibleFrame.height / 2)
    guard normalizedX * normalizedX + normalizedY * normalizedY <= 1 else { return nil }

    let controlPoint = CGPoint(
      x: point.x - visibleFrame.minX,
      y: point.y - visibleFrame.minY
    )
    return controlView.hitTest(controlPoint, with: event)
  }
}
#endif
#endif
