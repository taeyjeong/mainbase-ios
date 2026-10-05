import SwiftUI

/// The editable link rows for a report, on the clock-out sheet and in EditReportSheet: a link
/// and a short description per row, with "Add another link". Blank rows are ignored on save;
/// an invalid row is outlined in red.
struct ReportLinkFields: View {
    @Binding var links: [ReportLinkDraft]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Links")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)

            ForEach($links) { $draft in
                linkFields(for: $draft)
            }

            Button {
                links.append(ReportLinkDraft())
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Add another link")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(AppColors.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add another link")
        }
    }

    private func linkFields(for draft: Binding<ReportLinkDraft>) -> some View {
        let limitedDescription = Binding(
            get: { draft.wrappedValue.description },
            set: { draft.wrappedValue.description = String($0.prefix(ReportLinkDraft.descriptionLimit)) }
        )

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                TextField("Paste a link", text: draft.url)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.text)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if links.count > 1 {
                    Button {
                        links.removeAll { $0.id == draft.wrappedValue.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textSecondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove link")
                }
            }
            .padding(12)

            Divider()

            HStack(spacing: 8) {
                TextField("Describe the link", text: limitedDescription)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.text)
                Text("\(draft.wrappedValue.description.count)/\(ReportLinkDraft.descriptionLimit)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(12)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(draft.wrappedValue.isInvalid ? Color.red : AppColors.border, lineWidth: 1)
        )
        .overlay(alignment: .bottomLeading) {
            if draft.wrappedValue.isInvalid {
                Text(draft.wrappedValue.url.trimmingCharacters(in: .whitespaces).isEmpty
                     ? "Add the link or clear the description"
                     : "Enter a valid link, like docs.google.com/…")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .offset(y: 16)
            }
        }
        .padding(.bottom, draft.wrappedValue.isInvalid ? 16 : 0)
    }
}
