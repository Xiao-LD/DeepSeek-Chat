import SwiftUI
import UIKit
import JavaScriptCore // 引入 JS 引擎

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
    
    struct Segment { let text: String; let isCode: Bool; let language: String? }
    
    func parseMarkdown(_ text: String) -> [Segment] {
        var segments: [Segment] = []
        let pattern = "```(.*?)\\n([\\s\\S]*?)```"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var lastEnd = 0
        for match in matches {
            if match.range.location > lastEnd {
                let normalText = nsString.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
                segments.append(Segment(text: normalText, isCode: false, language: nil))
            }
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
    @State private var showJSResult = false
    @State private var jsResult = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language?.uppercased() ?? "CODE").font(.caption2).bold().foregroundStyle(.gray)
                Spacer()
                
                // 如果是 JS 代码，提供沙盒运行按钮
                if language?.lowercased() == "javascript" || language?.lowercased() == "js" {
                    Button {
                        let context = JSContext()
                        let result = context?.evaluateScript(code)
                        jsResult = result?.toString() ?? "执行成功 (无返回值)"
                        showJSResult = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Image(systemName: "play.circle").font(.caption).foregroundStyle(.green)
                    }
                    .padding(.trailing, 8)
                }
                
                Button {
                    UIPasteboard.general.string = code
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.caption).foregroundStyle(copied ? .green : .gray)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8).background(Color(white: 0.15))
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code).font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Color(red: 0.8, green: 0.9, blue: 1.0)).padding(12)
            }
        }
        .background(Color(white: 0.1)).clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .padding(.vertical, 4)
        .alert("JS 运行结果", isPresented: $showJSResult) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(jsResult)
        }
    }
}