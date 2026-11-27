import SwiftUI

final class StorybookControllerReference<Controller: AnyObject> {
  weak var controller: Controller?

  init(_ controller: Controller?) {
    self.controller = controller
  }
}

extension EnvironmentValues {
  @Entry var storybook_isFullScreenPresentation = false
}

#if canImport(UIKit)
private struct StorybookOpenFullScreenPageKey: EnvironmentKey {
  static let defaultValue: (@MainActor (BookPage) -> Void)? = nil
}

extension EnvironmentValues {
  @Entry var storybook_controllerReference: StorybookControllerReference<UIViewController>?

  public var storybook_targetViewController: UIViewController? {
    get { storybook_controllerReference?.controller }
    set { storybook_controllerReference = newValue.map(StorybookControllerReference.init) }
  }

  var storybook_openFullScreenPage: (@MainActor (BookPage) -> Void)? {
    get { self[StorybookOpenFullScreenPageKey.self] }
    set { self[StorybookOpenFullScreenPageKey.self] = newValue }
  }
}

extension View {
  func _storybookTargetViewController(
    _ reference: StorybookControllerReference<UIViewController>
  ) -> some View {
    environment(\.storybook_controllerReference, reference)
  }
}
#elseif os(macOS)
import AppKit

extension EnvironmentValues {
  @Entry var storybook_controllerReference: StorybookControllerReference<NSViewController>?

  /// The nearest Storybook controller used for native AppKit presentations.
  ///
  /// The environment does not retain the controller, so hosted content cannot
  /// create a cycle with the controller that owns it.
  public var storybook_targetViewController: NSViewController? {
    get { storybook_controllerReference?.controller }
    set { storybook_controllerReference = newValue.map(StorybookControllerReference.init) }
  }
}

extension View {
  func _storybookTargetViewController(
    _ reference: StorybookControllerReference<NSViewController>
  ) -> some View {
    environment(\.storybook_controllerReference, reference)
  }
}
#endif
