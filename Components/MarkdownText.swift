import SwiftUI

struct MarkdownText: View {
    let markdown: String

    var body: some View {
        if let attributed = try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .font(.body)
        } else {
            Text(markdown)
                .font(.body)
                .monospaced()
        }
    }
}