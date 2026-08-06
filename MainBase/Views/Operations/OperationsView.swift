import SwiftUI
import UniformTypeIdentifiers

struct OperationsView: View {
    @StateObject private var vm = OperationsViewModel()
    @State private var showingAddLink = false
    @State private var showingFileImporter = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.items.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(vm.items) { item in
                            OperationItemRow(item: item)
                                .listRowBackground(AppColors.cardBackground)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Operations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingAddLink = true
                        } label: {
                            Label("Add Link", systemImage: "link")
                        }
                        Button {
                            showingFileImporter = true
                        } label: {
                            Label("Add File", systemImage: "doc.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .task { vm.startListening() }
        .onDisappear { vm.stopListening() }
        .sheet(isPresented: $showingAddLink) {
            AddOperationLinkSheet(vm: vm)
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.pdf, .image]) { result in
            Task { await handleFileImport(result) }
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "shippingbox")
                .font(.system(size: 36))
                .foregroundColor(AppColors.textSecondary)
            Text("No items yet")
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleFileImport(_ result: Result<URL, Error>) async {
        guard case .success(let url) = result else { return }
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Could not access that file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url) else {
            errorMessage = "Could not read that file."
            return
        }
        let kind: OperationItemKind = (UTType(filenameExtension: url.pathExtension) ?? .data).conforms(to: .pdf) ? .pdf : .image
        let result = await vm.addFile(data: data, fileName: url.lastPathComponent, kind: kind)
        if !result.success { errorMessage = result.error }
    }
}

private struct OperationItemRow: View {
    let item: OperationItem

    var body: some View {
        Group {
            switch item.kind {
            case .link:
                if let url = URL(string: item.urlString) {
                    LinkThumbnailView(url: url)
                }
            case .image:
                Link(destination: URL(string: item.urlString) ?? URL(string: "https://")!) {
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: item.urlString)) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            } else {
                                Rectangle().fill(AppColors.border)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text(item.title)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.text)
                    }
                }
            case .pdf:
                Link(destination: URL(string: item.urlString) ?? URL(string: "https://")!) {
                    HStack(spacing: 12) {
                        Image(systemName: LinkPlatform.pdf.iconName)
                            .foregroundColor(LinkPlatform.pdf.tintColor)
                            .frame(width: 44, height: 44)
                            .background(AppColors.background)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text(item.title)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.text)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AddOperationLinkSheet: View {
    @ObservedObject var vm: OperationsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var urlString = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FormTextField(label: "Link", placeholder: "https://docs.google.com/...", text: $urlString)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                }
                .padding(20)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Add Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await handleSave() } }
                    }
                }
            }
        }
    }

    private func handleSave() async {
        isSaving = true
        errorMessage = nil
        let result = await vm.addLink(urlString: urlString)
        isSaving = false
        if result.success {
            dismiss()
        } else {
            errorMessage = result.error
        }
    }
}
