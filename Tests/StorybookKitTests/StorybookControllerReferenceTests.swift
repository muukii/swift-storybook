import Foundation
import Testing

@testable import StorybookKit

@Suite("Storybook controller references")
struct StorybookControllerReferenceTests {

  @Test("A presentation target is not retained by its environment reference")
  func presentationTargetIsWeak() {
    let reference = makeReference()

    #expect(reference.controller == nil)
  }

  private func makeReference() -> StorybookControllerReference<NSObject> {
    let controller = NSObject()
    let reference = StorybookControllerReference(controller)
    #expect(reference.controller === controller)
    return reference
  }
}
