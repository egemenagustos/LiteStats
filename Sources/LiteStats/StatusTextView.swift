import AppKit

/// Draws the menu bar text directly, skipping NSButtonCell's title layout.
final class StatusTextView: NSView {
    var font: NSFont = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)

    var text = "" {
        didSet {
            guard text != oldValue else { return }
            line = nil
            needsDisplay = true
        }
    }

    private var line: CTLine?

    override var allowsVibrancy: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidChangeEffectiveAppearance() {
        line = nil
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !text.isEmpty, let context = NSGraphicsContext.current?.cgContext else { return }
        if line == nil {
            let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.labelColor])
            line = CTLineCreateWithAttributedString(string)
        }
        guard let line else { return }

        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
        let x = ((bounds.width - width) / 2).rounded()
        let y = ((bounds.height - ascent - descent) / 2 + descent).rounded()

        context.textMatrix = .identity
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
    }
}
