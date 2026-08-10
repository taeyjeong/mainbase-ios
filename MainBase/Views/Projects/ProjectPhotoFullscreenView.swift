import SwiftUI
import UIKit

/// Full-bleed photo viewer opened via the carousel's maximize button. Locks the interface to
/// landscape while presented and restores free rotation on dismiss. Portrait photos are rotated
/// 90° so they read upright in landscape; every photo is scaled to fill the whole screen. Stays
/// up until the close button is tapped.
struct ProjectPhotoFullscreenView: View {
    let photoURLs: [String]
    let startIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int

    init(photoURLs: [String], startIndex: Int) {
        self.photoURLs = photoURLs
        self.startIndex = startIndex
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photoURLs.enumerated()), id: \.offset) { index, urlString in
                    GeometryReader { geo in
                        FillingPhoto(urlString: urlString, screenSize: geo.size)
                    }
                    .ignoresSafeArea()
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
            }
            .padding(16)
        }
        .onAppear { OrientationLock.lock(to: .landscape) }
        .onDisappear { OrientationLock.lock(to: .all) }
    }
}

/// Loads a single photo and draws it filling `screenSize`. A portrait source image (taller than it
/// is wide) is laid out into a size-swapped frame and rotated 90° so that, once rotated, it covers
/// the landscape screen; a landscape image just scales to fill directly.
private struct FillingPhoto: View {
    let urlString: String
    let screenSize: CGSize
    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                let isPortrait = uiImage.size.height > uiImage.size.width
                // For a 90° rotation the pre-rotation frame must have width/height swapped, so the
                // rotated result lands exactly on the screen's dimensions.
                let layoutSize = isPortrait
                    ? CGSize(width: screenSize.height, height: screenSize.width)
                    : screenSize
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: layoutSize.width, height: layoutSize.height)
                    .rotationEffect(isPortrait ? .degrees(90) : .degrees(0))
                    .frame(width: screenSize.width, height: screenSize.height)
                    .clipped()
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(width: screenSize.width, height: screenSize.height)
            }
        }
        .task(id: urlString) { await load() }
    }

    private func load() async {
        guard let url = URL(string: urlString) else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return }
        await MainActor.run { uiImage = image }
    }
}
