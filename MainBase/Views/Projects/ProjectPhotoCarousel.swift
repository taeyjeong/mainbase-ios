import PhotosUI
import SwiftUI
import UIKit

/// Swipeable photo header shown at the top of a project's detail view, with a "+" button
/// to add photos (uploaded to Firebase Storage) and a maximize button for a landscape,
/// full-bleed view. Add-only — no delete/reorder.
struct ProjectPhotoCarousel: View {
    let projectId: String
    let photoURLs: [String]
    @ObservedObject var vm: ProjectsViewModel

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var showingFullscreen = false
    @State private var currentIndex = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if photoURLs.isEmpty {
                emptyPlaceholder
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(photoURLs.enumerated()), id: \.offset) { index, urlString in
                        AsyncImage(url: URL(string: urlString)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Rectangle().fill(AppColors.border)
                            }
                        }
                        .tag(index)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture { showingFullscreen = true }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 220)
            }

            HStack(spacing: 10) {
                if !photoURLs.isEmpty {
                    Button {
                        showingFullscreen = true
                    } label: {
                        CarouselControlIcon {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }

                PhotosPicker(selection: $selectedItems, matching: .images) {
                    CarouselControlIcon {
                        if isUploading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(isUploading)
            }
            .padding(12)
        }
        .fullScreenCover(isPresented: $showingFullscreen) {
            ProjectPhotoFullscreenView(photoURLs: photoURLs, startIndex: currentIndex)
        }
        .onChange(of: selectedItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await uploadSelectedPhotos(newItems) }
        }
    }

    private var emptyPlaceholder: some View {
        Rectangle()
            .fill(AppColors.border)
            .frame(height: 140)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundColor(AppColors.textSecondary)
            )
    }

    private func uploadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        isUploading = true
        let images = await loadImages(from: items)
        selectedItems = []
        if !images.isEmpty {
            _ = await vm.addPhotos(projectId: projectId, images: images)
        }
        isUploading = false
    }
}

private struct CarouselControlIcon<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(width: 34, height: 34)
            .background(Color.black.opacity(0.45))
            .clipShape(Circle())
    }
}
