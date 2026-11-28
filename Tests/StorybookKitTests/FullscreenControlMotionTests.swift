import CoreGraphics
import Testing

@testable import StorybookKit

@Suite("Fullscreen control motion")
struct FullscreenControlMotionTests {

  private let bounds = CGRect(x: 32, y: 90, width: 338, height: 720)

  @Test("Projection stays inside safe-area center bounds")
  func projectionClampsToSafeAreaBounds() {
    let target = FullscreenControlMotion.snapTarget(
      projectedPosition: CGPoint(x: -100, y: -50),
      centerBounds: bounds
    )

    #expect(target == CGPoint(x: bounds.minX, y: bounds.minY))
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

  @Test("A keyboard above safe-area center bounds does not invert them")
  func nearTopKeyboardPreservesSafeAreaBounds() {
    let centerBounds = FullscreenControlMotion.centerBounds(
      in: CGRect(x: 0, y: 0, width: 402, height: 874),
      safeAreaInsets: .init(top: 62, left: 0, bottom: 34, right: 0),
      controlSize: CGSize(width: 56, height: 56),
      margin: 12,
      keyboardTop: 80
    )

    #expect(centerBounds.minY == 102)
    #expect(centerBounds.maxY == 800)
    #expect(centerBounds.minY >= 62)
    #expect(centerBounds.height.isFinite)
  }

  @Test("An undersized safe area collapses at its midpoint")
  func invertedCenterRangeStaysInsideSafeArea() {
    let centerBounds = FullscreenControlMotion.centerBounds(
      in: CGRect(x: 0, y: 0, width: 402, height: 100),
      safeAreaInsets: .init(top: 62, left: 0, bottom: 34, right: 0),
      controlSize: CGSize(width: 56, height: 56),
      margin: 12,
      keyboardTop: nil
    )

    #expect(centerBounds.minY == 64)
    #expect(centerBounds.maxY == 64)
    #expect(centerBounds.height == 0)
    #expect(centerBounds.minY >= 62)
    #expect(centerBounds.maxY <= 66)
  }
}
