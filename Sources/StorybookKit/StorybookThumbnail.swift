import SwiftUI
#if canImport(UIKit)
import UIKit
typealias StorybookThumbnailImage = UIImage
#elseif os(macOS)
import AppKit
typealias StorybookThumbnailImage = NSImage
#endif

enum StorybookThumbnail {
  case image(StorybookThumbnailImage)
  case unavailable(String)
}

@MainActor
final class StorybookThumbnailCache: ObservableObject {

  private final class Entry {
    let thumbnail: StorybookThumbnail

    init(_ thumbnail: StorybookThumbnail) {
      self.thumbnail = thumbnail
    }
  }

  private let entries = NSCache<NSString, Entry>()

  init() {
    entries.countLimit = 40
    entries.totalCostLimit = 24 * 1_024 * 1_024
  }

  func thumbnail(for page: BookPage, colorScheme: ColorScheme) -> StorybookThumbnail {
    let appearance: StorybookViewportAppearance = colorScheme == .dark ? .dark : .light
    let key = "\(page.id.index)|\(appearance.rawValue)" as NSString
    if let entry = entries.object(forKey: key) {
      return entry.thumbnail
    }
    let thumbnail = StorybookThumbnailRenderer.render(page: page, appearance: appearance)
    let cost: Int
    switch thumbnail {
    case .image:
      cost = Int(StorybookThumbnailRenderer.size.width * StorybookThumbnailRenderer.size.height) * 4
    case .unavailable:
      cost = 0
    }
    entries.setObject(Entry(thumbnail), forKey: key, cost: cost)
    return thumbnail
  }
}

@MainActor
enum StorybookThumbnailRenderer {

  static let size = CGSize(width: 480, height: 360)

  static func render(
    page: BookPage,
    appearance: StorybookViewportAppearance
  ) -> StorybookThumbnail {
    let content: AnyView
    switch page.viewPortPreview() {
    case .viewport(let makeView):
      content = makeView()
    #if canImport(UIKit)
    case .uiView(let makeView):
      content = AnyView(ThumbnailNativeView(makeView: makeView))
    #elseif os(macOS)
    case .nsView(let makeView):
      content = AnyView(_ViewHost(instantiate: makeView))
    #endif
    case .presentedViewController:
      // Catalog generation must never present controllers over the user's UI.
      return .unavailable("Open this preview to view its controller.")
    case .unsupported(let reason):
      return .unavailable(reason)
    }

    let viewport = StorybookViewport(descriptor: page.descriptor) {
      AnyView(
        content
          .frame(width: size.width, height: size.height)
          .clipped()
          .background(appearance == .dark ? Color.black : Color.white)
      )
    }
    do {
      return .image(
        try StorybookViewportRenderer.render(
          viewport, width: size.width, scale: 1, appearance: appearance
        ).image
      )
    } catch {
      return .unavailable(error.localizedDescription)
    }
  }
}

#if canImport(UIKit)
private struct ThumbnailNativeView: UIViewRepresentable {
  let makeView: @MainActor () -> UIView

  func makeUIView(context: Context) -> UIView { makeView() }
  func updateUIView(_ uiView: UIView, context: Context) {}

  func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIView, context: Context) -> CGSize? {
    let limit = proposal.replacingUnspecifiedDimensions(by: StorybookThumbnailRenderer.size)
    let fitted = uiView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    let natural = uiView.sizeThatFits(limit)
    func dimension(_ values: CGFloat..., limit: CGFloat) -> CGFloat {
      min(values.first { $0.isFinite && $0 > 0 } ?? limit, limit)
    }
    return CGSize(
      width: dimension(fitted.width, natural.width, uiView.bounds.width, limit: limit.width),
      height: dimension(fitted.height, natural.height, uiView.bounds.height, limit: limit.height)
    )
  }
}
#endif
