import LinkPresentation
import SwiftUI

/// In-memory cache so re-rendering a chat message (e.g. on every snapshot update)
/// doesn't refetch link metadata it already has.
private final class LinkMetadataCache {
    static let shared = LinkMetadataCache()
    private var cache = NSCache<NSURL, LPLinkMetadata>()

    func metadata(for url: URL) -> LPLinkMetadata? { cache.object(forKey: url as NSURL) }
    func store(_ metadata: LPLinkMetadata, for url: URL) { cache.setObject(metadata, forKey: url as NSURL) }
}

/// Rich link preview for a URL detected in chat text. Wraps `LPLinkView` for a real
/// title/image preview, with a `LinkPlatform` icon+color badge overlay that's always
/// shown instantly — useful since Google Doc/Sheet links often can't unfurl without
/// the viewer being signed into that Google account.
struct LinkThumbnailView: View {
    let url: URL

    @State private var metadata: LPLinkMetadata?

    private var platform: LinkPlatform { LinkPlatform.detect(from: url) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let metadata {
                    LinkPreviewRepresentable(metadata: metadata)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10).stroke(AppColors.border, lineWidth: 1)
                        )
                        .overlay(
                            Text(url.absoluteString)
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.primary)
                                .lineLimit(1)
                                .padding(.horizontal, 10),
                            alignment: .leading
                        )
                }
            }
            .frame(height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 4) {
                Image(systemName: platform.iconName)
                Text(platform.label)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(platform.tintColor)
            .clipShape(Capsule())
            .padding(6)
        }
        .task(id: url) {
            if let cached = LinkMetadataCache.shared.metadata(for: url) {
                metadata = cached
                return
            }
            let provider = LPMetadataProvider()
            if let fetched = try? await provider.startFetchingMetadata(for: url) {
                LinkMetadataCache.shared.store(fetched, for: url)
                metadata = fetched
            }
        }
    }
}

private struct LinkPreviewRepresentable: UIViewRepresentable {
    let metadata: LPLinkMetadata

    func makeUIView(context: Context) -> LPLinkView {
        LPLinkView(metadata: metadata)
    }

    func updateUIView(_ uiView: LPLinkView, context: Context) {
        uiView.metadata = metadata
    }
}
