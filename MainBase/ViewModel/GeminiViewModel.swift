import Foundation
import Combine
import FirebaseFunctions

@MainActor
final class GeminiViewModel: ObservableObject {
    @Published var prompt: String = ""
    @Published private(set) var submittedPrompt: String = ""
    @Published private(set) var response: String = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    var canSubmit: Bool {
        !isLoading && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Sends the prompt to the askGemini Cloud Function, which holds the Gemini API key server-side.
    func submit() async {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty, !isLoading else { return }

        isLoading = true
        errorMessage = nil
        submittedPrompt = trimmedPrompt
        response = ""
        defer { isLoading = false }

        let callable = Functions.functions().httpsCallable("askGemini")
        callable.timeoutInterval = 120
        do {
            let result = try await callable.call(["prompt": trimmedPrompt])
            guard let text = (result.data as? [String: Any])?["text"] as? String else {
                errorMessage = "Gemini returned an unexpected response."
                return
            }
            response = text
            prompt = ""
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }

    func clear() {
        prompt = ""
        submittedPrompt = ""
        response = ""
        errorMessage = nil
    }
}
