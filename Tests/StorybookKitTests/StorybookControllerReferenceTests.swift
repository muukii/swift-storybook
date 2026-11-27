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

  #if canImport(UIKit)
  @Test("A bare UIViewController releases after its autorelease pool drains")
  func bareViewControllerReleases() {
    let reference = autoreleasepool {
      WeakViewControllerReference(UIViewController())
    }

    #expect(reference.value == nil)
  }

  @Test("A plain UIHostingController child does not retain its parent")
  func plainHostingChildReleasesWithParent() {
    let reference = plainHostingChildParentReference()

    #expect(reference.value == nil)
  }
  #endif

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
    autoreleasepool {
      #if os(macOS)
      _ = NSApplication.shared
      #endif

      let controller = _ViewController(content: Text("Lifecycle"))
      let reference: WeakViewControllerReference<StorybookTestViewController> = .init(controller)
      _ = controller.view
      return reference
    }
  }

  #if canImport(UIKit)
  private func plainHostingChildParentReference() -> WeakViewControllerReference<UIViewController> {
    autoreleasepool {
      let parent = UIViewController()
      let child = UIHostingController(rootView: Text("Control"))
      parent.addChild(child)
      parent.view.addSubview(child.view)
      child.didMove(toParent: parent)
      return WeakViewControllerReference(parent)
    }
  }
  #endif
}

private final class WeakViewControllerReference<Controller: AnyObject> {
  weak var value: Controller?

  init(_ value: Controller) {
    self.value = value
  }
}
