#if canImport(UIKit)
import UIKit

@MainActor
protocol StorybookWindowMotionHandler: AnyObject {
  func storybookWindowDidReceiveShake()
}

#if !targetEnvironment(macCatalyst)
/// A window that routes completed shake gestures to its active fullscreen Storybook page.
///
/// Use this as the `UIWindowSceneDelegate` window when fullscreen shake actions are needed.
/// While a fullscreen page is active, the window becomes first responder only when no text
/// input is editing. Text fields and text views retain native first-responder and shake-to-undo
/// behavior.
@MainActor
public final class StorybookWindow: UIWindow {

  private weak var activeFullscreenMotionHandler: (any StorybookWindowMotionHandler)?
  private var editingTextInputs: [ObjectIdentifier: WeakTextInputReference] = [:]
  private var isObservingNotifications = false

  public override var canBecomeFirstResponder: Bool {
    activeFullscreenMotionHandler != nil
  }

  func activateFullscreenMotionHandler(_ handler: any StorybookWindowMotionHandler) {
    activeFullscreenMotionHandler = handler
    observeFullscreenInputChangesIfNeeded()
    collectEditingTextInputs(in: self)
    restoreFirstResponderIfAvailable()
  }

  func deactivateFullscreenMotionHandler(
    _ handler: (any StorybookWindowMotionHandler)? = nil
  ) {
    if let handler, activeFullscreenMotionHandler !== handler {
      return
    }

    activeFullscreenMotionHandler = nil
    editingTextInputs.removeAll()
    NotificationCenter.default.removeObserver(self)
    isObservingNotifications = false

    if isFirstResponder {
      _ = resignFirstResponder()
    }
  }

  func restoreFirstResponderIfAvailable() {
    guard activeFullscreenMotionHandler != nil,
      hasEditingTextInput == false,
      isKeyWindow,
      isFirstResponder == false
    else {
      return
    }

    _ = becomeFirstResponder()
  }

  public override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    guard motion == .motionShake,
      let activeFullscreenMotionHandler,
      hasEditingTextInput == false
    else {
      super.motionEnded(motion, with: event)
      return
    }

    activeFullscreenMotionHandler.storybookWindowDidReceiveShake()
  }

  @objc private func textInputDidBeginEditing(_ notification: Notification) {
    guard let textInput = notification.object as? UIView,
      textInput.window === self
    else {
      return
    }

    editingTextInputs[ObjectIdentifier(textInput)] = .init(textInput)
  }

  @objc private func textInputDidEndEditing(_ notification: Notification) {
    guard let textInput = notification.object as? UIView,
      editingTextInputs.removeValue(forKey: ObjectIdentifier(textInput)) != nil,
      hasEditingTextInput == false
    else {
      return
    }

    Task { @MainActor [weak self] in
      self?.restoreFirstResponderIfAvailable()
    }
  }

  @objc private func windowDidBecomeKey(_ notification: Notification) {
    restoreFirstResponderIfAvailable()
  }

  private var hasEditingTextInput: Bool {
    editingTextInputs = editingTextInputs.filter { input in
      guard let view = input.value.view, view.window === self else { return false }

      if let textField = view as? UITextField {
        return textField.isEditing
      }
      if let textView = view as? UITextView {
        return textView.isFirstResponder
      }
      return false
    }
    return editingTextInputs.isEmpty == false
  }

  private func observeFullscreenInputChangesIfNeeded() {
    guard isObservingNotifications == false else { return }

    let center = NotificationCenter.default
    center.addObserver(
      self,
      selector: #selector(textInputDidBeginEditing(_:)),
      name: UITextField.textDidBeginEditingNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(textInputDidEndEditing(_:)),
      name: UITextField.textDidEndEditingNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(textInputDidBeginEditing(_:)),
      name: UITextView.textDidBeginEditingNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(textInputDidEndEditing(_:)),
      name: UITextView.textDidEndEditingNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(windowDidBecomeKey(_:)),
      name: UIWindow.didBecomeKeyNotification,
      object: self
    )
    isObservingNotifications = true
  }

  private func collectEditingTextInputs(in view: UIView) {
    if let textField = view as? UITextField, textField.isEditing {
      editingTextInputs[ObjectIdentifier(textField)] = .init(textField)
    } else if let textView = view as? UITextView, textView.isFirstResponder {
      editingTextInputs[ObjectIdentifier(textView)] = .init(textView)
    }

    view.subviews.forEach { collectEditingTextInputs(in: $0) }
  }
}

@MainActor
final class StorybookWindowSession {

  private weak var window: StorybookWindow?
  private weak var handler: (any StorybookWindowMotionHandler)?

  func activate(window candidate: UIWindow?, handler: any StorybookWindowMotionHandler) {
    guard let candidate = candidate as? StorybookWindow else { return }

    if self.window !== candidate || self.handler !== handler {
      deactivate()
      self.window = candidate
      self.handler = handler
    }

    candidate.activateFullscreenMotionHandler(handler)
  }

  func restoreFirstResponderIfAvailable() {
    window?.restoreFirstResponderIfAvailable()
  }

  func deactivate(_ expectedHandler: (any StorybookWindowMotionHandler)? = nil) {
    if let expectedHandler, handler !== expectedHandler {
      return
    }

    if let window {
      window.deactivateFullscreenMotionHandler(handler)
    }

    window = nil
    handler = nil
  }
}

@MainActor
private final class WeakTextInputReference {
  weak var view: UIView?

  init(_ view: UIView) {
    self.view = view
  }
}
#else
@MainActor
final class StorybookWindowSession {

  func activate(window: UIWindow?, handler: any StorybookWindowMotionHandler) {}

  func restoreFirstResponderIfAvailable() {}

  func deactivate(_ expectedHandler: (any StorybookWindowMotionHandler)? = nil) {}
}
#endif
#endif
