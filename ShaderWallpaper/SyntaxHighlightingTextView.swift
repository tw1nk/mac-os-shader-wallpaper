import SwiftUI
import AppKit

enum ShaderEditorSyntax {
    case metal
    case yaml
}

struct SyntaxHighlightingTextView: NSViewRepresentable {
    @Binding var text: String
    let syntax: ShaderEditorSyntax
    let isEditable: Bool

    private static let editorBackgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1)
    private static let editorTextColor = NSColor(calibratedWhite: 0.92, alpha: 1)
    private static let baseTypingAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
        .foregroundColor: editorTextColor,
        .backgroundColor: editorBackgroundColor
    ]

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = Self.editorBackgroundColor
        let textView = NSTextView()
        textView.isRichText = false
        textView.isEditable = isEditable
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.drawsBackground = true
        textView.backgroundColor = Self.editorBackgroundColor
        textView.textColor = Self.editorTextColor
        textView.insertionPointColor = Self.editorTextColor
        textView.typingAttributes = Self.baseTypingAttributes
        textView.delegate = context.coordinator
        textView.string = text
        scroll.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.highlightSoon()
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scroll.documentView as? NSTextView else { return }
        textView.isEditable = isEditable
        scroll.backgroundColor = Self.editorBackgroundColor
        textView.backgroundColor = Self.editorBackgroundColor
        textView.textColor = Self.editorTextColor
        textView.insertionPointColor = Self.editorTextColor
        textView.typingAttributes = Self.baseTypingAttributes
        if textView.string != text {
            textView.string = text
            context.coordinator.highlightSoon()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxHighlightingTextView
        weak var textView: NSTextView?
        private var workItem: DispatchWorkItem?
        private var isHighlighting = false

        init(_ parent: SyntaxHighlightingTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard !isHighlighting, let textView else { return }
            parent.text = textView.string
            highlightSoon()
        }

        func highlightSoon() {
            workItem?.cancel()
            let item = DispatchWorkItem { [weak self] in self?.highlight() }
            workItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
        }

        private func highlight() {
            guard let textView else { return }
            let string = textView.string as NSString
            let selected = textView.selectedRanges
            let attributed = NSMutableAttributedString(string: textView.string)
            let full = NSRange(location: 0, length: string.length)
            attributed.addAttributes(SyntaxHighlightingTextView.baseTypingAttributes, range: full)

            let rules: [(String, NSColor)]
            switch parent.syntax {
            case .metal:
                rules = [
                    (#"//.*|/\*[\s\S]*?\*/"#, NSColor(calibratedRed: 0.50, green: 0.65, blue: 0.50, alpha: 1)),
                    (#""([^"\\]|\\.)*""#, NSColor(calibratedRed: 0.95, green: 0.60, blue: 0.55, alpha: 1)),
                    (#"\b(fragment|vertex|constant|using|namespace|return|float|float2|float3|float4|int|uint|half|metal|texture2d|sampler|mix|sin|cos)\b"#, NSColor(calibratedRed: 0.45, green: 0.70, blue: 1.00, alpha: 1)),
                    (#"\[\[[^\]]+\]\]"#, NSColor(calibratedRed: 0.80, green: 0.60, blue: 1.00, alpha: 1)),
                    (#"\b\d+(?:\.\d+)?\b"#, NSColor(calibratedRed: 1.00, green: 0.75, blue: 0.35, alpha: 1))
                ]
            case .yaml:
                rules = [
                    (#"#.*"#, NSColor(calibratedRed: 0.50, green: 0.65, blue: 0.50, alpha: 1)),
                    (#"(?m)^\s*[A-Za-z_][A-Za-z0-9_.-]*(?=:)"#, NSColor(calibratedRed: 0.45, green: 0.70, blue: 1.00, alpha: 1)),
                    (#""([^"\\]|\\.)*"|'[^']*'"#, NSColor(calibratedRed: 0.95, green: 0.60, blue: 0.55, alpha: 1)),
                    (#"\b(true|false)\b"#, NSColor(calibratedRed: 0.80, green: 0.60, blue: 1.00, alpha: 1)),
                    (#"\b\d+(?:\.\d+){0,2}\b"#, NSColor(calibratedRed: 1.00, green: 0.75, blue: 0.35, alpha: 1))
                ]
            }
            for (pattern, color) in rules {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                regex.enumerateMatches(in: textView.string, range: full) { match, _, _ in
                    guard let range = match?.range else { return }
                    attributed.addAttribute(.foregroundColor, value: color, range: range)
                }
            }
            isHighlighting = true
            textView.textStorage?.setAttributedString(attributed)
            textView.typingAttributes = SyntaxHighlightingTextView.baseTypingAttributes
            textView.selectedRanges = selected
            isHighlighting = false
        }
    }
}
