import SwiftUI
import Testing

#if canImport(UIKit)
import UIKit
private typealias StorybookTestViewController = UIViewController
#elseif os(macOS)
import AppKit
private typealias StorybookTestViewController = NSViewController
#endif

@testable import StorybookKit

@MainActor
@Suite("Storybook target view controller environment")
struct StorybookControllerReferenceTests {

  @Test("The environment remains alive without retaining its target controller")
  func environmentDoesNotRetainTarget() {
    let environment = environmentAfterTargetRelease()

    #expect(environment.storybook_targetViewController == nil)
  }

  @Test("A loaded hosting controller releases with its owner")
  func loadedHostingControllerReleases() {
    let reference = loadedHostingControllerReference()

    #expect(reference.value == nil)
  }

  private func environmentAfterTargetRelease() -> EnvironmentValues {
    var environment = EnvironmentValues()
    let controller = StorybookTestViewController()
    environment.storybook_targetViewController = controller
    #expect(environment.storybook_targetViewController === controller)
    return environment
  }

  private func loadedHostingControllerReference() -> WeakViewControllerReference<
    StorybookTestViewController
  > {
    #if os(macOS)
    _ = NSApplication.shared
    #endif

    let controller = _ViewController(content: Text("Lifecycle"))
    let reference: WeakViewControllerReference<StorybookTestViewController> = .init(controller)
    _ = controller.view
    return reference
  }
}

private final class WeakViewControllerReference<Controller: AnyObject> {
  weak var value: Controller?

  init(_ value: Controller) {
    self.value = value
  }
}
