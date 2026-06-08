import AppKit
import STTextView

struct MetalSyntaxHighlightingPlugin: STPlugin {
    func setUp(context: any Context) {
        DispatchQueue.main.async { [coordinator = context.coordinator, weak textView = context.textView] in
            guard let textView else { return }
            coordinator.highlight(textView)
        }
        context.events.onDidChangeText { [coordinator = context.coordinator, weak textView = context.textView] _, _ in
            guard let textView else { return }
            DispatchQueue.main.async { coordinator.highlight(textView) }
        }
    }

    func makeCoordinator(context: CoordinatorContext) -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private var isHighlighting = false

        private let baseColor = NSColor(calibratedWhite: 0.92, alpha: 1)

        private let rules: [(pattern: String, color: NSColor)] = [
            (#"(?m)^\s*#\s*\w+.*$"#, NSColor(calibratedRed: 0.80, green: 0.60, blue: 1.00, alpha: 1)),
            (#"//.*|/\*[\s\S]*?\*/"#, NSColor(calibratedRed: 0.50, green: 0.65, blue: 0.50, alpha: 1)),
            (#"\"([^\"\\]|\\.)*\""#, NSColor(calibratedRed: 0.95, green: 0.60, blue: 0.55, alpha: 1)),
            (#"\b(fragment|vertex|kernel|constant|device|thread|threadgroup|texture|sampler|using|namespace|return|if|else|for|while|do|switch|case|default|break|continue|struct|class|template|typename|constexpr|inline)\b"#, NSColor(calibratedRed: 0.45, green: 0.70, blue: 1.00, alpha: 1)),
            (#"\b(float|float2|float3|float4|float2x2|float3x3|float4x4|half|half2|half3|half4|int|int2|int3|int4|uint|uint2|uint3|uint4|short|ushort|bool|bool2|bool3|bool4|char|uchar|void)\b"#, NSColor(calibratedRed: 0.40, green: 0.85, blue: 0.85, alpha: 1)),
            (#"\b(abs|acos|asin|atan|ceil|clamp|cos|cross|distance|dot|exp|floor|fract|length|log|max|min|mix|normalize|pow|reflect|refract|saturate|sin|smoothstep|sqrt|step|tan)\b(?=\s*\()"#, NSColor(calibratedRed: 0.95, green: 0.80, blue: 0.45, alpha: 1)),
            (#"\[\[[^\]]+\]\]"#, NSColor(calibratedRed: 0.80, green: 0.60, blue: 1.00, alpha: 1)),
            (#"\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?[fhu]*\b"#, NSColor(calibratedRed: 1.00, green: 0.75, blue: 0.35, alpha: 1))
        ]

        func highlight(_ textView: STTextView) {
            guard !isHighlighting, let text = textView.text else { return }
            let nsText = text as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            guard fullRange.length > 0 else { return }

            isHighlighting = true
            textView.removeRenderingAttribute(.foregroundColor, range: fullRange)
            textView.addRenderingAttributes([.foregroundColor: baseColor], range: fullRange)
            for rule in rules {
                guard let regex = try? NSRegularExpression(pattern: rule.pattern) else { continue }
                regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                    guard let range = match?.range, range.location != NSNotFound else { return }
                    textView.addRenderingAttributes([.foregroundColor: rule.color], range: range)
                }
            }
            isHighlighting = false
        }
    }
}
