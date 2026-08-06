import SwiftUI

/// Admin-only card (shown in ProfileSheetView's admin section) for viewing and adding
/// project "Mains" — the color-coded category every project is tagged with.
struct ManageProjectMainsView: View {
    @StateObject private var adminVM = ProjectMainsAdminViewModel()
    @State private var showingAddMain = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Project Mains")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.text)
                Spacer()
                Button {
                    showingAddMain = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(.bottom, 16)

            if adminVM.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if adminVM.mains.isEmpty {
                Text("No Mains yet.")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ForEach(Array(adminVM.mains.enumerated()), id: \.element.id) { index, main in
                    if index > 0 {
                        Divider()
                            .padding(.vertical, 8)
                    }
                    HStack {
                        Circle()
                            .fill(Color(hex: main.colorHex))
                            .frame(width: 18, height: 18)
                        Text(main.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.text)
                        Spacer()
                    }
                }
            }

            if let errorMessage = adminVM.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        )
        .onAppear { adminVM.startListening() }
        .onDisappear { adminVM.stopListening() }
        .sheet(isPresented: $showingAddMain) {
            AddProjectMainSheet(adminVM: adminVM)
        }
    }
}

private struct AddProjectMainSheet: View {
    @ObservedObject var adminVM: ProjectMainsAdminViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var color = Color(hex: "#0A84FF")
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FormTextField(label: "Name", placeholder: "e.g. New Client App", text: $name)
                    ColorPicker("Color", selection: $color, supportsOpacity: false)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.text)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                }
                .padding(20)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("New Main")
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
        let result = await adminVM.addMain(name: name, colorHex: color.toHex())
        isSaving = false
        if result.success {
            dismiss()
        } else {
            errorMessage = result.error
        }
    }
}
