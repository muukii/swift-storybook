import SwiftUI

struct StorybookThumbnailGallery: View {

  struct Entry: Identifiable {
    var id: BookPage.ID { page.id }
    let page: BookPage
    let folderPath: String
  }

  let nodes: [Book.Node]
  let cache: StorybookThumbnailCache
  let onSelect: (BookPage) -> Void

  #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  #endif
  @State private var minimumCardWidth: CGFloat = 248

  var body: some View {
    let entries = Self.entries(in: nodes)
    ScrollView {
      if entries.isEmpty {
        ContentUnavailableView("No Previews", systemImage: "square.grid.2x2")
          .frame(maxWidth: .infinity)
          .padding(.top, 40)
      } else {
        LazyVGrid(columns: columns, spacing: 16) {
          ForEach(entries) { entry in
            Button {
              onSelect(entry.page)
            } label: {
              StorybookThumbnailCard(entry: entry, cache: cache)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.page.title)
            .accessibilityHint("Open preview. \(entry.folderPath)")
            .accessibilityIdentifier(
              "storybook.thumbnail|\(entry.page.descriptor.accessibilityIdentifier)")
          }
        }
        .padding(16)
      }
    }
    .onGeometryChange(for: CGFloat.self) { geometry in
      min(248, max(1, geometry.size.width - 32))
    } action: { minimumCardWidth in
      self.minimumCardWidth = minimumCardWidth
    }
    .accessibilityIdentifier("storybook.thumbnails")
  }

  private var columns: [GridItem] {
    #if os(iOS)
      if horizontalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize {
        return Array(repeating: GridItem(.flexible(minimum: 0), alignment: .top), count: 2)
      }
    #endif
    return [GridItem(.adaptive(minimum: minimumCardWidth, maximum: 360), alignment: .top)]
  }

  static func entries(in nodes: [Book.Node], path: [String] = []) -> [Entry] {
    var seen: Set<BookPage.ID> = []
    return nodes.flatMap { node -> [Entry] in
      switch node {
      case .page(let page):
        return [Entry(page: page, folderPath: path.joined(separator: " / "))]
      case .folder(let folder):
        return entries(in: folder.contents, path: path + [folder.title])
      }
    }.filter { seen.insert($0.id).inserted }
  }
}

private struct StorybookThumbnailCard: View {

  let entry: StorybookThumbnailGallery.Entry
  let cache: StorybookThumbnailCache

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var thumbnail: StorybookThumbnail?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      labels
      thumbnailContent
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(.rect)
    .help(help)
    .task(id: colorScheme) {
      thumbnail = nil
      await Task.yield()
      guard Task.isCancelled == false else { return }
      thumbnail = cache.thumbnail(for: entry.page, colorScheme: colorScheme)
    }
    .onDisappear { thumbnail = nil }
  }

  private var thumbnailContent: some View {
    ZStack {
      Rectangle().fill(.background)
      switch thumbnail {
      case .image(let image):
        #if canImport(UIKit)
          Image(uiImage: image).resizable().scaledToFit()
        #elseif os(macOS)
          Image(nsImage: image).resizable().scaledToFit()
        #endif
      case .unavailable:
        VStack(spacing: 8) {
          Image(systemName: "photo")
          Text("Open to Preview").font(.caption)
        }
        .foregroundStyle(.secondary)
      case nil:
        ProgressView().controlSize(.small)
      }
    }
    .aspectRatio(4.0 / 3.0, contentMode: .fit)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.separator)
    }
    .accessibilityHidden(true)
  }

  private var labels: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(entry.page.title)
        .font(.subheadline.weight(.semibold))
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
        .fixedSize(horizontal: false, vertical: true)
      Text(entry.folderPath.isEmpty ? entry.page.descriptor.fileID : entry.folderPath)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var help: String {
    let source = "\(entry.page.descriptor.fileID):\(entry.page.descriptor.line)"
    if case .unavailable(let reason) = thumbnail {
      return "\(source)\n\(reason)"
    }
    return source
  }
}
