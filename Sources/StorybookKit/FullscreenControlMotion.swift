import CoreGraphics

enum FullscreenControlMotion {

  struct Insets: Equatable {
    let top: CGFloat
    let left: CGFloat
    let bottom: CGFloat
    let right: CGFloat
  }

  static func centerBounds(
    in bounds: CGRect,
    safeAreaInsets: Insets,
    controlSize: CGSize,
    margin: CGFloat,
    keyboardTop: CGFloat?
  ) -> CGRect {
    let halfWidth = controlSize.width / 2
    let halfHeight = controlSize.height / 2
    let minX = bounds.minX + safeAreaInsets.left + halfWidth + margin
    let maxX = bounds.maxX - safeAreaInsets.right - halfWidth - margin
    let minY = bounds.minY + safeAreaInsets.top + halfHeight + margin
    var maxY = bounds.maxY - safeAreaInsets.bottom - halfHeight - margin

    if let keyboardTop {
      maxY = min(maxY, keyboardTop - halfHeight - margin)
    }

    let resolvedMinX = min(minX, maxX)
    let resolvedMinY = min(minY, maxY)

    return CGRect(
      x: resolvedMinX,
      y: resolvedMinY,
      width: max(0, maxX - minX),
      height: max(0, maxY - minY)
    )
  }

  static func snapTarget(
    from center: CGPoint,
    velocity: CGPoint,
    centerBounds: CGRect,
    projectionDuration: CGFloat = 0.2,
    cancelled: Bool = false
  ) -> CGPoint {
    let velocity = cancelled ? .zero : velocity
    let projectedX = clamp(
      center.x + velocity.x * projectionDuration,
      minimum: centerBounds.minX,
      maximum: centerBounds.maxX
    )
    let projectedY = clamp(
      center.y + velocity.y * projectionDuration,
      minimum: centerBounds.minY,
      maximum: centerBounds.maxY
    )

    return CGPoint(
      x: projectedX < centerBounds.midX ? centerBounds.minX : centerBounds.maxX,
      y: projectedY
    )
  }

  static func normalizedInitialVelocity(velocity: CGFloat, distance: CGFloat) -> CGFloat {
    guard velocity.isFinite,
      distance.isFinite,
      abs(distance) > .ulpOfOne
    else {
      return 0
    }

    return velocity / distance
  }

  static func clamp(_ point: CGPoint, to bounds: CGRect) -> CGPoint {
    CGPoint(
      x: clamp(point.x, minimum: bounds.minX, maximum: bounds.maxX),
      y: clamp(point.y, minimum: bounds.minY, maximum: bounds.maxY)
    )
  }

  private static func clamp(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
    let lowerBound = min(minimum, maximum)
    let upperBound = max(minimum, maximum)
    return max(lowerBound, min(value, upperBound))
  }
}
