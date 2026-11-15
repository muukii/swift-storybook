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

  @State private var minimumCardWidth: CGFloat = 248

  var body: some View {
    let entries = Self.entries(in: nodes)
    ScrollView {
      if entries.isEmpty {
        ContentUnavailableView("No Previews", systemImage: "square.grid.2x2")
          .frame(maxWidth: .infinity)
          .padding(.top, 40)
      } else {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: minimumCardWidth, maximum: 360))], spacing: 16
        ) {
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

  static func entries(in nodes: [Book.Node], path: [String] = []) -> [Entry] {
    nodes.flatMap { node -> [Entry] in
      switch node {
      case .page(let page):
        return [Entry(page: page, folderPath: path.joined(separator: " / "))]
      case .folder(let folder):
        return entries(in: folder.contents, path: path + [folder.title])
      }
    }
  }
}

private struct StorybookThumbnailCard: View {

  let entry: StorybookThumbnailGallery.Entry
  let cache: StorybookThumbnailCache

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var thumbnail: StorybookThumbnail?

  var body: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        verticalContent
      } else {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 8) {
            thumbnailContent.frame(width: 96)
            labels.frame(minWidth: 120, idealWidth: 120, maxWidth: .infinity)
          }
          verticalContent
        }
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.separator)
    }
    .help(help)
    .task(id: colorScheme) {
      thumbnail = nil
      await Task.yield()
      guard Task.isCancelled == false else { return }
      thumbnail = cache.thumbnail(for: entry.page, colorScheme: colorScheme)
    }
    .onDisappear { thumbnail = nil }
  }

  private var verticalContent: some View {
    VStack(alignment: .leading, spacing: 8) {
      thumbnailContent
      labels
    }
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
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
