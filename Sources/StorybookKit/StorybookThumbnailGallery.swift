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

  var body: some View {
    let entries = Self.entries(in: nodes)
    ScrollView {
      if entries.isEmpty {
        ContentUnavailableView("No Previews", systemImage: "square.grid.2x2")
          .frame(maxWidth: .infinity)
          .padding(.top, 40)
      } else {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 260))], spacing: 16) {
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
  @State private var thumbnail: StorybookThumbnail?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
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
      .clipped()
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(entry.page.title)
          .font(.subheadline.weight(.medium))
          .lineLimit(2, reservesSpace: true)
        Text(entry.folderPath.isEmpty ? entry.page.descriptor.fileID : entry.folderPath)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(.quaternary.opacity(0.3))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.1))
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

  private var help: String {
    let source = "\(entry.page.descriptor.fileID):\(entry.page.descriptor.line)"
    if case .unavailable(let reason) = thumbnail {
      return "\(source)\n\(reason)"
    }
    return source
  }
}
