#if canImport(UIKit) && !targetEnvironment(macCatalyst)
import Testing
import UIKit

@testable import StorybookKit

@MainActor
@Suite("Storybook window shake routing")
struct StorybookWindowTests {

  @Test("Only the active fullscreen page receives a shake")
  func routesShakeToActiveFullscreenPage() {
    let window = StorybookWindow(frame: .zero)
    let previousPage = ShakeHandlerSpy()
    let activePage = ShakeHandlerSpy()

    window.activateFullscreenMotionHandler(previousPage)
    window.activateFullscreenMotionHandler(activePage)
    window.motionEnded(.motionShake, with: nil)

    #expect(previousPage.shakeCount == 0)
    #expect(activePage.shakeCount == 1)

    window.deactivateFullscreenMotionHandler(previousPage)
    window.motionEnded(.motionShake, with: nil)

    #expect(activePage.shakeCount == 2)

    window.deactivateFullscreenMotionHandler(activePage)
    window.motionEnded(.motionShake, with: nil)

    #expect(activePage.shakeCount == 2)
  }

  @Test("A live nonediting text input does not suppress shake")
  func doesNotSuppressShakeForLiveNoneditingTextInput() {
    let window = StorybookWindow(frame: .zero)
    let page = ShakeHandlerSpy()
    let textField = UITextField(frame: .zero)
    window.addSubview(textField)
    window.activateFullscreenMotionHandler(page)

    NotificationCenter.default.post(
      name: UITextField.textDidBeginEditingNotification,
      object: textField
    )
    window.motionEnded(.motionShake, with: nil)
    #expect(page.shakeCount == 1)

    window.deactivateFullscreenMotionHandler(page)
  }

  @Test("A detached but live text input does not keep shake disabled")
  func doesNotKeepShakeDisabledForDetachedTextInput() {
    let window = StorybookWindow(frame: .zero)
    let page = ShakeHandlerSpy()
    let textField = UITextField(frame: .zero)
    window.addSubview(textField)
    window.activateFullscreenMotionHandler(page)

    NotificationCenter.default.post(
      name: UITextField.textDidBeginEditingNotification,
      object: textField
    )
    textField.removeFromSuperview()
    window.motionEnded(.motionShake, with: nil)
    #expect(page.shakeCount == 1)

    window.deactivateFullscreenMotionHandler(page)
  }
}

@MainActor
private final class ShakeHandlerSpy: StorybookWindowMotionHandler {
  private(set) var shakeCount = 0

  func storybookWindowDidReceiveShake() {
    shakeCount += 1
  }
}
#endif
