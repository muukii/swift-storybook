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
    let safeMinX = bounds.minX + safeAreaInsets.left
    let safeMaxX = bounds.maxX - safeAreaInsets.right
    let safeMinY = bounds.minY + safeAreaInsets.top
    let safeMaxY = bounds.maxY - safeAreaInsets.bottom
    let minX = safeMinX + halfWidth + margin
    let maxX = safeMaxX - halfWidth - margin
    let minY = safeMinY + halfHeight + margin
    var maxY = safeMaxY - halfHeight - margin

    if let keyboardTop, keyboardTop.isFinite {
      let keyboardMaxY = keyboardTop - halfHeight - margin
      if keyboardMaxY >= minY {
        maxY = min(maxY, keyboardMaxY)
      }
    }

    let horizontalRange = resolvedCenterRange(
      minimum: minX,
      maximum: maxX,
      safeMinimum: safeMinX,
      safeMaximum: safeMaxX
    )
    let verticalRange = resolvedCenterRange(
      minimum: minY,
      maximum: maxY,
      safeMinimum: safeMinY,
      safeMaximum: safeMaxY
    )

    return CGRect(
      x: horizontalRange.lower,
      y: verticalRange.lower,
      width: max(0, horizontalRange.upper - horizontalRange.lower),
      height: max(0, verticalRange.upper - verticalRange.lower)
    )
  }

  static func snapTarget(
    projectedPosition: CGPoint,
    centerBounds: CGRect
  ) -> CGPoint {
    let projected = clamp(projectedPosition, to: centerBounds)

    return CGPoint(
      x: projected.x < centerBounds.midX ? centerBounds.minX : centerBounds.maxX,
      y: projected.y
    )
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

  private static func resolvedCenterRange(
    minimum: CGFloat,
    maximum: CGFloat,
    safeMinimum: CGFloat,
    safeMaximum: CGFloat
  ) -> (lower: CGFloat, upper: CGFloat) {
    guard minimum <= maximum else {
      let safeMidpoint = (min(safeMinimum, safeMaximum) + max(safeMinimum, safeMaximum)) / 2
      return (safeMidpoint, safeMidpoint)
    }

    return (minimum, maximum)
  }
}
