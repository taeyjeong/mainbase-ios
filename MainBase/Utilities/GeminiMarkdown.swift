import Foundation

enum GeminiMarkdown {
    /// Gemini answers in Markdown; render inline styling (bold, italics, code, links) while keeping line breaks.
    static func attributed(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
