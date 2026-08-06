import SwiftUI

/// Full-bleed photo viewer opened via the carousel's maximize button. Locks the
/// interface to landscape while presented, and restores free rotation on dismiss.
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
                    AsyncImage(url: URL(string: urlString)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        default:
                            ProgressView().tint(.white)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

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
