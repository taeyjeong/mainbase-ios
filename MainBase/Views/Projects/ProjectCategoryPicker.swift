import SwiftUI

/// Shared Main / Label / Sublabels picker used by both AddProjectSheet and EditProjectSheet.
struct ProjectCategoryPicker: View {
    let projectMains: [ProjectMain]
    @Binding var selectedMainId: String
    @Binding var selectedLabel: ProjectLabel
    @Binding var selectedSublabels: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Main")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.text)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(projectMains) { main in
                            MainSwatchButton(
                                main: main,
                                isSelected: selectedMainId == main.id,
                                action: { selectedMainId = main.id }
                            )
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Label")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.text)
                Picker("Label", selection: $selectedLabel) {
                    ForEach(ProjectLabel.allCases, id: \.self) { label in
                        Text(label.displayName).tag(label)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedLabel) { _, _ in
                    selectedSublabels = []
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Sublabels")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.text)
                SublabelChipsView(
                    options: selectedLabel.sublabelOptions,
                    selected: $selectedSublabels
                )
            }
        }
    }
}

private struct MainSwatchButton: View {
    let main: ProjectMain
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: main.colorHex))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle().stroke(AppColors.text, lineWidth: isSelected ? 2 : 0)
                            .padding(-3)
                    )
                Text(main.name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(AppColors.text)
                    .lineLimit(1)
                    .frame(maxWidth: 70)
            }
        }
    }
}

struct SublabelChipsView: View {
    let options: [String]
    @Binding var selected: Set<String>

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = selected.contains(option)
                Button {
                    if isSelected {
                        selected.remove(option)
                    } else {
                        selected.insert(option)
                    }
                } label: {
                    Text(option)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isSelected ? .white : AppColors.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? AppColors.primary : AppColors.cardBackground)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(AppColors.border, lineWidth: isSelected ? 0 : 1)
                        )
                }
            }
        }
    }
}
