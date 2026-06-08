import SwiftUI
import AppKit
import STTextView

struct SourceCodeEditorView: NSViewRepresentable {
    @Binding var text: String
    let isEditable: Bool
    let findRequest: Int

    private static let editorBackgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1)
    private static let editorTextColor = NSColor(calibratedWhite: 0.92, alpha: 1)

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = STTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? STTextView else { return scrollView }
        configure(textView, context: context)
        textView.text = text
        textView.addPlugin(MetalSyntaxHighlightingPlugin())
        textView.textDelegate = context.coordinator
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? STTextView else { return }
        configure(textView, context: context)
        if textView.text != text {
            textView.text = text
        }
        context.coordinator.showFindInterfaceIfNeeded(findRequest)
    }

    private func configure(_ textView: STTextView, context: Context) {
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = Self.editorTextColor
        textView.backgroundColor = Self.editorBackgroundColor
        textView.enclosingScrollView?.backgroundColor = Self.editorBackgroundColor
        textView.enclosingScrollView?.drawsBackground = true
        textView.insertionPointColor = Self.editorTextColor
        textView.isHorizontallyResizable = true
        textView.showsLineNumbers = true
        textView.gutterView?.drawSeparator = true
        textView.highlightSelectedLine = true
        textView.isIncrementalSearchingEnabled = true
        textView.textFinder.incrementalSearchingShouldDimContentView = true
    }

    final class Coordinator: NSObject, STTextViewDelegate {
        var parent: SourceCodeEditorView
        weak var textView: STTextView?
        private var handledFindRequest = 0

        init(_ parent: SourceCodeEditorView) {
            self.parent = parent
        }

        func textViewDidChangeText(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.text ?? ""
        }

        func showFindInterfaceIfNeeded(_ request: Int) {
            guard request != handledFindRequest, let textView else { return }
            handledFindRequest = request
            textView.window?.makeFirstResponder(textView)
            let item = NSMenuItem()
            item.tag = NSTextFinder.Action.showFindInterface.rawValue
            textView.performTextFinderAction(item)
        }
    }
}
