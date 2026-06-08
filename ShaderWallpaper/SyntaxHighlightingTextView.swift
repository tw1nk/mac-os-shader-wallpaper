import SwiftUI
import AppKit

private final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private let foregroundColor = NSColor.secondaryLabelColor
    private let backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1)

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 44
        needsDisplay = true
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        backgroundColor.setFill()
        rect.fill()

        guard
            let textView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer
        else { return }

        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let paragraphRanges = lineNumberRanges(in: textView.string as NSString)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular),
            .foregroundColor: foregroundColor
        ]

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, glyphRange, _ in
            let characterIndex = layoutManager.characterIndexForGlyph(at: glyphRange.location)
            let lineNumber = paragraphRanges.partitioningIndex { $0.location > characterIndex }
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: attributes)
            let y = usedRect.minY + textView.textContainerOrigin.y
            let x = self.ruleThickness - size.width - 8
            label.draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
        }
    }

    private func lineNumberRanges(in string: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        string.enumerateSubstrings(in: NSRange(location: 0, length: string.length), options: [.byParagraphs, .substringNotRequired]) { _, range, _, _ in
            ranges.append(range)
        }
        if ranges.isEmpty || NSMaxRange(ranges[ranges.count - 1]) < string.length {
            ranges.append(NSRange(location: string.length, length: 0))
        }
        return ranges
    }
}

private extension Array {
    func partitioningIndex(where belongsInSecondPartition: (Element) throws -> Bool) rethrows -> Int {
        var low = 0
        var high = count
        while low < high {
            let mid = low + (high - low) / 2
            if try belongsInSecondPartition(self[mid]) {
                high = mid
            } else {
                low = mid + 1
            }
        }
        return low
    }
}

enum ShaderEditorSyntax {
    case metal
    case yaml
}

struct SyntaxHighlightingTextView: NSViewRepresentable {
    @Binding var text: String
    let syntax: ShaderEditorSyntax
    let isEditable: Bool
    let showsLineNumbers: Bool

    init(text: Binding<String>, syntax: ShaderEditorSyntax, isEditable: Bool, showsLineNumbers: Bool = false) {
        self._text = text
        self.syntax = syntax
        self.isEditable = isEditable
        self.showsLineNumbers = showsLineNumbers
    }

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
        scroll.hasVerticalRuler = showsLineNumbers
        scroll.rulersVisible = showsLineNumbers
        let textView = NSTextView(frame: scroll.contentView.bounds)
        textView.isRichText = true
        textView.importsGraphics = false
        textView.usesFontPanel = false
        textView.allowsDocumentBackgroundColorChange = false
        textView.isEditable = isEditable
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.minSize = NSSize(width: 0, height: scroll.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.drawsBackground = true
        textView.backgroundColor = Self.editorBackgroundColor
        textView.textColor = Self.editorTextColor
        textView.insertionPointColor = Self.editorTextColor
        textView.typingAttributes = Self.baseTypingAttributes
        textView.delegate = context.coordinator
        textView.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: Self.baseTypingAttributes))
        scroll.documentView = textView
        if showsLineNumbers {
            scroll.verticalRulerView = LineNumberRulerView(textView: textView)
        }
        context.coordinator.textView = textView
        context.coordinator.highlightSoon()
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scroll.documentView as? NSTextView else { return }
        textView.isEditable = isEditable
        scroll.hasVerticalRuler = showsLineNumbers
        scroll.rulersVisible = showsLineNumbers
        if showsLineNumbers, scroll.verticalRulerView == nil {
            scroll.verticalRulerView = LineNumberRulerView(textView: textView)
        }
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
            textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
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
