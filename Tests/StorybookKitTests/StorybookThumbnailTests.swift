import SwiftUI
import Testing

@testable import StorybookKit

#if canImport(UIKit)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

@Suite("Thumbnail catalog")
@MainActor
struct StorybookThumbnailTests {

  @Test("Snapshots have a bounded viewport even for very tall content")
  func boundedViewport() throws {
    let page = BookPage(title: "Tall") {
      Color(red: 1, green: 0, blue: 0).frame(height: 10_000)
    }
    let renderedImage = try image(StorybookThumbnailRenderer.render(page: page, appearance: .light))
    #expect(renderedImage.size == StorybookThumbnailRenderer.size)
    #if os(macOS)
      let bitmap = try #require(renderedImage.representations.first as? NSBitmapImageRep)
      #expect(bitmap.pixelsWide == 480)
      #expect(bitmap.pixelsHigh == 360)
      let color = try #require(bitmap.colorAt(x: 240, y: 180)?.usingColorSpace(.deviceRGB))
      #expect(color.redComponent > 0.9)
      #expect(color.greenComponent < 0.1)
    #else
      let color = try pixel(in: renderedImage)
      #expect(color[0] > 230)
      #expect(color[1] < 25)
    #endif
  }

  @Test("The same declaration and appearance reuse the image; another appearance rerenders")
  func cachedAppearance() throws {
    var creations = 0
    let page = BookPage(title: "Cached") {
      creations += 1
      return AppearanceFixture()
    }
    let cache = StorybookThumbnailCache()
    let light = try image(cache.thumbnail(for: page, colorScheme: .light))
    let repeated = try image(cache.thumbnail(for: page, colorScheme: .light))
    #expect(light === repeated)
    #expect(creations == 1)
    let dark = try image(cache.thumbnail(for: page, colorScheme: .dark))
    #expect(light !== dark)
    #expect(creations == 2)
    #if os(macOS)
      let lightBitmap = try #require(light.representations.first as? NSBitmapImageRep)
      let darkBitmap = try #require(dark.representations.first as? NSBitmapImageRep)
      let lightColor = try #require(
        lightBitmap.colorAt(x: 240, y: 180)?.usingColorSpace(.deviceRGB))
      let darkColor = try #require(darkBitmap.colorAt(x: 240, y: 180)?.usingColorSpace(.deviceRGB))
      #expect(lightColor.redComponent > 0.9)
      #expect(darkColor.redComponent < 0.1)
    #else
      #expect(try pixel(in: light)[0] > 230)
      #expect(try pixel(in: dark)[0] < 25)
    #endif
  }

  @Test("SwiftUI text survives the window-backed snapshot")
  func textPixels() throws {
    let text = BookPage(title: "Text") {
      Text("Thumbnail").font(.system(size: 48)).foregroundStyle(Color.black)
    }
    let empty = BookPage(title: "Empty") { Color.white }
    let textImage = try image(StorybookThumbnailRenderer.render(page: text, appearance: .light))
    let emptyImage = try image(StorybookThumbnailRenderer.render(page: empty, appearance: .light))
    #if canImport(UIKit)
      #expect(try #require(textImage.pngData()) != #require(emptyImage.pngData()))
    #else
      let textBitmap = try #require(textImage.representations.first as? NSBitmapImageRep)
      let emptyBitmap = try #require(emptyImage.representations.first as? NSBitmapImageRep)
      #expect(
        try #require(textBitmap.representation(using: .png, properties: [:]))
          != #require(emptyBitmap.representation(using: .png, properties: [:]))
      )
    #endif
  }

  @Test("Distinct declarations with identical names and source locations never share images")
  func declarationIdentity() throws {
    var firstCreations = 0
    var secondCreations = 0
    let first = BookPage("Fixture.swift", 10, title: "Duplicate") {
      firstCreations += 1
      return Color.red
    }
    let second = BookPage("Fixture.swift", 10, title: "Duplicate") {
      secondCreations += 1
      return Color.blue
    }
    let cache = StorybookThumbnailCache()
    let firstImage = try image(cache.thumbnail(for: first, colorScheme: .light))
    let secondImage = try image(cache.thumbnail(for: second, colorScheme: .light))
    #expect(firstImage !== secondImage)
    #expect(firstCreations == 1)
    #expect(secondCreations == 1)
  }

  @Test("Controller factories are not invoked by thumbnail generation")
  func controllerPlaceholder() {
    var creations = 0
    let page = page {
      .presentedViewController {
        creations += 1
        #if canImport(UIKit)
          return UIViewController()
        #else
          return NSViewController()
        #endif
      }
    }
    let thumbnail = StorybookThumbnailRenderer.render(page: page, appearance: .light)
    guard case .unavailable(let reason) = thumbnail else {
      Issue.record("A controller thumbnail must be a placeholder")
      return
    }
    #expect(reason.contains("controller"))
    #expect(creations == 0)
  }

  @Test("Unsupported reasons are cached without opening the page or changing history")
  func unsupportedPlaceholder() {
    var attempts = 0
    let page = page {
      attempts += 1
      return .unsupported("Unsupported preview structure")
    }
    let store = BookStore(book: Book(title: "Test") { page })
    let history = store.historyPages.map(\.id)
    let cache = StorybookThumbnailCache()
    for _ in 0..<2 {
      guard case .unavailable(let reason) = cache.thumbnail(for: page, colorScheme: .light) else {
        Issue.record("Expected an unsupported thumbnail")
        return
      }
      #expect(reason == "Unsupported preview structure")
    }
    #expect(attempts == 1)
    #expect(store.historyPages.map(\.id) == history)
  }

  @Test("Native view previews produce images without presenting a controller")
  func nativeView() throws {
    let page = page {
      #if canImport(UIKit)
        .uiView {
          let view = UIView(frame: .init(x: 0, y: 0, width: 80, height: 40))
          view.backgroundColor = .green
          return view
        }
      #else
        .nsView {
          let view = NSView(frame: .init(x: 0, y: 0, width: 80, height: 40))
          view.wantsLayer = true
          view.layer?.backgroundColor = NSColor.green.cgColor
          return view
        }
      #endif
    }
    let renderedImage = try image(StorybookThumbnailRenderer.render(page: page, appearance: .light))
    #expect(renderedImage.size == StorybookThumbnailRenderer.size)
    #if os(macOS)
      let bitmap = try #require(renderedImage.representations.first as? NSBitmapImageRep)
      let color = try #require(bitmap.colorAt(x: 240, y: 180)?.usingColorSpace(.deviceRGB))
      #expect(color.greenComponent > 0.9)
      #expect(color.redComponent < 0.1)
    #else
      let bytes = try pixel(in: renderedImage)
      #expect(bytes[1] > 230)
      #expect(bytes[0] < 25)
    #endif
  }

  @Test("Gallery entries preserve nested folder paths, page identity, and filtered nodes")
  func galleryEntries() {
    let first = BookPage(title: "Same name") { Color.red }
    let second = BookPage(title: "Same name") { Color.blue }
    let root = BookPage(title: "Root") { Color.green }
    let folder = Book(title: "Module") {
      Book(title: "Components.swift") {
        first
        second
      }
    }
    let entries = StorybookThumbnailGallery.entries(in: [.folder(folder), .page(root)])
    #expect(entries.map(\.id) == [first.id, second.id, root.id])
    #expect(
      entries.map(\.folderPath) == [
        "Module / Components.swift", "Module / Components.swift", "",
      ])
    #expect(StorybookThumbnailGallery.entries(in: [.page(second)]).map(\.id) == [second.id])
    #expect(StorybookThumbnailGallery.entries(in: []).isEmpty)
  }

  #if canImport(UIKit)
    @Test("Native scrolling content uses the bounded viewport in both appearances")
    func nativeScrollView() throws {
      let page = page {
        .uiView {
          let root = UIView()
          root.backgroundColor = .systemBackground
          let scrollView = UIScrollView()
          let stack = UIStackView()
          stack.axis = .vertical
          stack.spacing = 12
          root.addSubview(scrollView)
          scrollView.translatesAutoresizingMaskIntoConstraints = false
          NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: root.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
          ])
          scrollView.addSubview(stack)
          stack.translatesAutoresizingMaskIntoConstraints = false
          NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(
              equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(
              equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(
              equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(
              equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(
              equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
          ])
          for _ in 0..<10 {
            let section = UIView()
            section.backgroundColor = .blue
            section.heightAnchor.constraint(equalToConstant: 120).isActive = true
            stack.addArrangedSubview(section)
          }
          return root
        }
      }
      let cache = StorybookThumbnailCache()
      for colorScheme in [ColorScheme.light, .dark, .light] {
        let renderedImage = try image(cache.thumbnail(for: page, colorScheme: colorScheme))
        #expect(renderedImage.size == StorybookThumbnailRenderer.size)
        let color = try pixel(in: renderedImage)
        #expect(color[2] > 230)
        #expect(color[0] < 25)
        #expect(color[1] < 25)
      }
    }
  #endif

  private func image(_ thumbnail: StorybookThumbnail) throws -> StorybookThumbnailImage {
    guard case .image(let image) = thumbnail else {
      if case .unavailable(let reason) = thumbnail { Issue.record("\(reason)") }
      throw ThumbnailTestError.missingImage
    }
    return image
  }

  #if canImport(UIKit)
    private func pixel(in image: UIImage) throws -> [UInt8] {
      let cgImage = try #require(image.cgImage)
      let pixel = try #require(cgImage.cropping(to: .init(x: 240, y: 180, width: 1, height: 1)))
      var bytes = [UInt8](repeating: 0, count: 4)
      let context = try #require(
        CGContext(
          data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
          space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
      context.draw(pixel, in: .init(x: 0, y: 0, width: 1, height: 1))
      return bytes
    }
  #endif

  private func page(
    preview: @escaping @MainActor () -> StorybookViewPortPreview
  ) -> BookPage {
    BookPage(
      fileID: "ThumbnailTests/Fixture.swift", line: 1, title: "Fixture", usesScrollView: false,
      destination: {
        Issue.record("Thumbnail generation must not open the catalog destination")
        return AnyView(EmptyView())
      },
      viewPortPreview: preview
    )
  }
}

private enum ThumbnailTestError: Error {
  case missingImage
}

private struct AppearanceFixture: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    colorScheme == .dark ? Color.black : Color.white
  }
}
