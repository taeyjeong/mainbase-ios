import SwiftUI

struct GeminiView: View {
    @StateObject private var viewModel = GeminiViewModel()
    @FocusState private var isPromptFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !viewModel.submittedPrompt.isEmpty {
                        Text(viewModel.submittedPrompt)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }

                    if viewModel.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Thinking…").foregroundStyle(.secondary)
                        }
                    } else if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    } else if !viewModel.response.isEmpty {
                        Text(GeminiMarkdown.attributed(viewModel.response))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ContentUnavailableView(
                            "Ask Gemini",
                            systemImage: "sparkles",
                            description: Text("Type a prompt below to get a response from Google Gemini.")
                        )
                        .padding(.top, 60)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)

            Divider()

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask anything…", text: $viewModel.prompt, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($isPromptFocused)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                Button {
                    isPromptFocused = false
                    Task { await viewModel.submit() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                }
                .disabled(!viewModel.canSubmit)
            }
            .padding()
        }
        .navigationTitle("Gemini")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.submittedPrompt.isEmpty && !viewModel.isLoading {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { viewModel.clear() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { GeminiView() }
}
