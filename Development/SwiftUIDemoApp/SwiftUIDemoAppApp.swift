//
// Copyright (c) 2020 Eureka, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import StorybookKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit) && !targetEnvironment(macCatalyst)
@main
@MainActor
final class SwiftUIDemoAppDelegate: UIResponder, UIApplicationDelegate {

  func application(
    _ application: UIApplication,
    configurationForConnecting session: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(
      name: "Storybook Window Scene",
      sessionRole: session.role
    )
    configuration.delegateClass = SwiftUIDemoSceneDelegate.self
    return configuration
  }
}

@MainActor
final class SwiftUIDemoSceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    let window = StorybookWindow(windowScene: windowScene)
    window.rootViewController = UIHostingController(rootView: SwiftUIDemoRootView())
    self.window = window
    window.makeKeyAndVisible()
  }
}
#else
@main
struct SwiftUIDemoAppApp: App {

  var body: some Scene {
    WindowGroup {
      SwiftUIDemoRootView()
    }
    #if os(macOS)
    .defaultSize(width: 960, height: 700)
    #endif
  }
}
#endif

private struct SwiftUIDemoRootView: View {

  private let storybookLaunchRequest: StorybookLaunchRequest?
  #if canImport(UIKit)
  private let viewportExportPreparationFailure: String?
  private let viewportExportRequest: ViewportExportRequest
  #endif

  init() {
    let arguments = ProcessInfo.processInfo.arguments
    storybookLaunchRequest = .init(arguments: arguments)
    #if canImport(UIKit)
    let viewportExportRequest = ViewportExportRequest(arguments: arguments)
    self.viewportExportRequest = viewportExportRequest

    if let exportID = viewportExportRequest.exportID {
      do {
        try StorybookViewportArtifact.prepare(exportID: exportID)
        viewportExportPreparationFailure = nil
      } catch {
        viewportExportPreparationFailure = error.localizedDescription
      }
    } else {
      viewportExportPreparationFailure = nil
    }
    #endif
  }

  var body: some View {
    #if canImport(UIKit)
    switch viewportExportRequest {
    case .disabled:
      if let storybookLaunchRequest {
        Storybook(launchRequest: storybookLaunchRequest)
      } else {
        ContentView()
      }
    case .invalid(let message, _):
      StorybookViewportExportFailureView(message: message)
    case .request(let request):
      if let viewportExportPreparationFailure {
        StorybookViewportExportFailureView(message: viewportExportPreparationFailure)
      } else if let selector = storybookLaunchRequest?.pageSelector {
        StorybookViewportExportView(
          selector: selector,
          exportID: request.exportID,
          appearance: request.appearance
        )
      } else {
        StorybookViewportExportFailureView(
          message: "Viewport export requires an exact Storybook page selector."
        )
      }
    }
    #else
    Storybook(launchRequest: storybookLaunchRequest ?? .catalog)
      .frame(minWidth: 640, minHeight: 480)
    #endif
  }
}

private extension StorybookLaunchRequest {

  var pageSelector: BookPageSelector? {
    switch self {
    case .page(let selector), .fullScreenPage(let selector):
      selector
    case .catalog, .invalid:
      nil
    @unknown default:
      nil
    }
  }
}
