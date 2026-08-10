import SwiftUI

/// A grid of every photo on a project, opened from the project detail's top-right photo button.
/// Each cell has a delete button; deletion removes the photo from Firestore and Storage via the
/// view model, and the grid re-reads the live list so the removed photo disappears immediately.
struct ProjectPhotoGalleryView: View {
    let projectId: String
    @ObservedObject var vm: ProjectsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var photoPendingDeletion: String?
    @State private var deletingURLs: Set<String> = []
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 10)]

    /// Read live from the view model so a delete reflected in `vm.projects` updates the grid.
    private var photoURLs: [String] {
        vm.projects.first(where: { $0.id == projectId })?.photoURLs ?? []
    }

    var body: some View {
        NavigationStack {
            Group {
                if photoURLs.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(photoURLs, id: \.self) { urlString in
                                photoCell(urlString)
                            }
                        }
                        .padding(12)
                    }
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("All Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete this photo?",
                isPresented: Binding(get: { photoPendingDeletion != nil }, set: { if !$0 { photoPendingDeletion = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete Photo", role: .destructive) {
                    if let url = photoPendingDeletion { delete(url) }
                    photoPendingDeletion = nil
                }
                Button("Cancel", role: .cancel) { photoPendingDeletion = nil }
            }
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func photoCell(_ urlString: String) -> some View {
        let isDeleting = deletingURLs.contains(urlString)
        return AsyncImage(url: URL(string: urlString)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Rectangle().fill(AppColors.border)
            }
        }
        .frame(width: 104, height: 104)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.border, lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            Button {
                photoPendingDeletion = urlString
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.black.opacity(0.55)))
            }
            .padding(6)
            .disabled(isDeleting)
        }
        .overlay {
            if isDeleting {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.4))
                    ProgressView().tint(.white)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 34))
                .foregroundColor(AppColors.textSecondary)
            Text("No photos yet")
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func delete(_ urlString: String) {
        deletingURLs.insert(urlString)
        Task {
            let result = await vm.deletePhoto(projectId: projectId, photoURL: urlString)
            deletingURLs.remove(urlString)
            if !result.success { errorMessage = result.error }
        }
    }
}
