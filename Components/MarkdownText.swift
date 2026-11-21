import SwiftUI
import UIKit

struct MarkdownText: View {
    let markdown: String
    
    var body: some View {
        let segments = parseMarkdown(markdown)
        
        VStack(alignment: .leading, spacing: 8) {
            ForEach(segments.indices, id: \.self) { index in
                let segment = segments[index]
                if segment.isCode {
                    CodeBlockView(code: segment.text, language: segment.language)
                } else {
                    if let attributed = try? AttributedString(markdown: segment.text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                        Text(attributed).font(.body).textSelection(.enabled)
                    } else {
                        Text(segment.text).font(.body).textSelection(.enabled)
                    }
                }
            }
        }
    }
    
    struct Segment {
        let text: String
        let isCode: Bool
        let language: String?
    }
    
    // 简单的 Markdown 代码块提取器
    func parseMarkdown(_ text: String) -> [Segment] {
        var segments: [Segment] = []
        let pattern = "```(.*?)\\n([\\s\\S]*?)```"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var lastEnd = 0
        for match in matches {
            // 提取代码块前面的普通文本
            if match.range.location > lastEnd {
                let normalText = nsString.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
                segments.append(Segment(text: normalText, isCode: false, language: nil))
            }
            
            // 提取代码块内容
            let langRange = match.range(at: 1)
            let codeRange = match.range(at: 2)
            let lang = nsString.substring(with: langRange).trimmingCharacters(in: .whitespacesAndNewlines)
            let code = nsString.substring(with: codeRange)
            
            segments.append(Segment(text: code, isCode: true, language: lang))
            lastEnd = match.range.location + match.range.length
        }
        
        if lastEnd < nsString.length {
            segments.append(Segment(text: nsString.substring(from: lastEnd), isCode: false, language: nil))
        }
        
        return segments.isEmpty ? [Segment(text: text, isCode: false, language: nil)] : segments
    }
}

struct CodeBlockView: View {
    let code: String
    let language: String?
    @State private var copied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language?.uppercased() ?? "CODE")
                    .font(.caption2).bold()
                    .foregroundStyle(.gray)
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(copied ? .green : .gray)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(white: 0.15))
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Color(red: 0.8, green: 0.9, blue: 1.0)) // 淡淡的代码蓝
                    .padding(12)
            }
        }
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .padding(.vertical, 4)
    }
}