import SwiftUI

/// Full-screen ZStack pop-up over TimeTrackerView showing a Gemini-written report of the user's
/// month. The dimmed backdrop swallows taps, so the only way out is Done, which first asks
/// whether to save a generated report.
struct MonthlySummaryPopup: View {
    @ObservedObject var vm: MonthlySummaryViewModel
    @State private var askToSave = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}

            VStack(spacing: 0) {
                header
                Divider()
                ScrollView(showsIndicators: false) {
                    content
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                doneButton
            }
            .frame(maxWidth: 520)
            .frame(maxHeight: 620)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColors.cardBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
            .padding(.horizontal, 20)
            .padding(.vertical, 40)
        }
        .alert("Save this report?", isPresented: $askToSave) {
            Button("Save") { saveAndClose() }
            Button("Don't Save", role: .destructive) { vm.dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save your \(vm.monthTitle) report to look back at later.")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Monthly Report")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppColors.text)
                Text(vm.monthTitle)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
        }
        .padding(20)
    }

    @ViewBuilder
    private var content: some View {
        if vm.isGenerating {
            VStack(spacing: 12) {
                ProgressView()
                Text("Writing your report…")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                if vm.hasReport {
                    Text(GeminiMarkdown.attributed(vm.reportText))
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.text)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let errorMessage = vm.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    if !vm.hasReport {
                        Button("Try Again") { vm.regenerate() }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
        }
    }

    private var doneButton: some View {
        Button {
            if vm.hasReport {
                askToSave = true
            } else {
                vm.dismiss()
            }
        } label: {
            ZStack {
                if vm.isSaving {
                    ProgressView()
                } else {
                    Text("Done")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(vm.isSaving)
    }

    private func saveAndClose() {
        Task {
            if await vm.save() { vm.dismiss() }
        }
    }
}
