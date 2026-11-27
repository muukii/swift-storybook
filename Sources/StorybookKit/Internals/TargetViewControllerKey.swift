import SwiftUI

extension EnvironmentValues {
  @Entry var storybook_isFullScreenPresentation = false
}

#if canImport(UIKit)
private struct StorybookOpenFullScreenPageKey: EnvironmentKey {
  static let defaultValue: (@MainActor (BookPage) -> Void)? = nil
}

extension EnvironmentValues {
  @Entry public var storybook_targetViewController: UIViewController?

  var storybook_openFullScreenPage: (@MainActor (BookPage) -> Void)? {
    get { self[StorybookOpenFullScreenPageKey.self] }
    set { self[StorybookOpenFullScreenPageKey.self] = newValue }
  }
}
#elseif os(macOS)
import AppKit

extension EnvironmentValues {
  @Entry private var storybook_controllerReference: StorybookControllerReference?

  /// The nearest Storybook controller used for native AppKit presentations.
  ///
  /// The environment does not retain the controller, so hosted content cannot
  /// create a cycle with the controller that owns it.
  public var storybook_targetViewController: NSViewController? {
    get { storybook_controllerReference?.controller }
    set { storybook_controllerReference = newValue.map(StorybookControllerReference.init) }
  }
}

/// Makes the presentation target available without retaining its native owner.
private final class StorybookControllerReference {
  weak var controller: NSViewController?

  init(_ controller: NSViewController) {
    self.controller = controller
  }
}
#endif
