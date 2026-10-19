import AppKit

/// Draws the compact menu bar: a small icon per metric followed by its value,
/// with network speeds stacked on two lines.
///
/// Icons react to load: the CPU fan spins faster as load rises, the network
/// arrows flow while there is traffic, and the RAM and SSD gauges ease to new
/// values. The moving parts are Core Animation layers, so the animation runs
/// in the render server and the app itself stays idle between samples.
final class StatusBarView: NSView {
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    private static let smallFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
    private static let iconSize: CGFloat = 13
    private static let iconGap: CGFloat = 3
    private static let arrowWidth: CGFloat = 5
    private static let arrowGap: CGFloat = 2
    private static let spacing: CGFloat = 8
    /// Below this (bytes per second) a direction counts as idle.
    private static let activeRate = 2000.0

    var metrics: [Metric] = [] {
        didSet {
            guard metrics != oldValue else { return }
            needsDisplay = true
            needsLayout = true
        }
    }

    var animationsEnabled = true {
        didSet { updateAnimations() }
    }

    private var cpu: Double?
    private var memory: Double?
    private var upload: Double?
    private var download: Double?
    private var disk: Double?

    private let fanLayer = CAShapeLayer()
    private let memoryLayer = CAShapeLayer()
    private let diskLayer = CAShapeLayer()
    private let upClip = CALayer()
    private let downClip = CALayer()
    private let upArrows = CAShapeLayer()
    private let downArrows = CAShapeLayer()

    /// Speeds of the running animations, so they are only restarted when the
    /// rounded speed actually changes.
    private var fanSpeed = 0.0
    private var upSpeed = 0.0
    private var downSpeed = 0.0

    private enum Slot { case cpu, memory, up, down, disk }
    private var lines: [Slot: (text: String, line: CTLine)] = [:]

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        upClip.masksToBounds = true
        downClip.masksToBounds = true
        upClip.addSublayer(upArrows)
        downClip.addSublayer(downArrows)
        for gauge in [memoryLayer, diskLayer] {
            gauge.fillColor = nil
            gauge.lineCap = .butt
            gauge.strokeEnd = 0
        }
        for sublayer in [fanLayer, memoryLayer, diskLayer, upClip, downClip] {
            sublayer.isHidden = true
            layer?.addSublayer(sublayer)
        }
        applyColors()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(displayOptionsDidChange),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidChangeEffectiveAppearance() {
        lines.removeAll()
        applyColors()
        needsDisplay = true
    }

    override func viewDidChangeBackingProperties() {
        needsLayout = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
    }

    // MARK: - Values

    func update(cpu: Double?, memory: Double?, upload: Double?, download: Double?, disk: Double?) {
        self.cpu = cpu
        self.memory = memory
        self.upload = upload
        self.download = download
        self.disk = disk
        needsDisplay = true

        CATransaction.begin()
        CATransaction.setDisableActions(!canAnimate)
        CATransaction.setAnimationDuration(0.6)
        memoryLayer.strokeEnd = clamped(memory)
        diskLayer.strokeEnd = clamped(disk)
        upClip.opacity = isActive(upload) ? 1 : 0.4
        downClip.opacity = isActive(download) ? 1 : 0.4
        CATransaction.commit()
        updateAnimations()
    }

    // MARK: - Layout

    /// Width of the content for the given metrics, using the widest values so
    /// the status item length can stay fixed.
    static func width(for metrics: [Metric]) -> CGFloat {
        guard !metrics.isEmpty else { return 0 }
        let segments = metrics.reduce(0) { $0 + segmentWidth($1) }
        return segments + spacing * CGFloat(metrics.count - 1)
    }

    private static let percentWidth = textWidth("100%", font)
    private static let speedWidth = textWidth("888M", smallFont)

    private static func textWidth(_ text: String, _ font: NSFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private static func segmentWidth(_ metric: Metric) -> CGFloat {
        switch metric {
        case .network: return speedWidth + arrowGap + arrowWidth
        default: return iconSize + iconGap + percentWidth
        }
    }

    private func segmentOrigins() -> [(metric: Metric, x: CGFloat)] {
        var x = ((bounds.width - Self.width(for: metrics)) / 2).rounded()
        return metrics.map { metric in
            defer { x += Self.segmentWidth(metric) + Self.spacing }
            return (metric, x)
        }
    }

    private func iconRect(at x: CGFloat) -> NSRect {
        NSRect(x: x, y: (bounds.midY - Self.iconSize / 2).rounded(), width: Self.iconSize, height: Self.iconSize)
    }

    private func chipBody(_ icon: NSRect) -> NSRect {
        NSRect(x: icon.minX + 0.5, y: icon.midY - 3.5, width: icon.width - 1, height: 7)
    }

    /// Arrows sit right of the speeds, which are padded to a fixed width so
    /// the numbers end right next to them.
    private func arrowRects(at x: CGFloat) -> (up: NSRect, down: NSRect) {
        let x = x + Self.speedWidth + Self.arrowGap
        let height = Self.smallFont.capHeight
        let up = NSRect(x: x, y: bounds.midY + 1, width: Self.arrowWidth, height: height)
        let down = NSRect(x: x, y: bounds.midY - 1 - height, width: Self.arrowWidth, height: height)
        return (up, down)
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let scale = window?.backingScaleFactor ?? 2
        for sublayer in [fanLayer, memoryLayer, diskLayer, upClip, downClip, upArrows, downArrows] {
            sublayer.contentsScale = scale
        }
        let shown = Set(metrics)
        fanLayer.isHidden = !shown.contains(.cpu)
        memoryLayer.isHidden = !shown.contains(.memory)
        diskLayer.isHidden = !shown.contains(.disk)
        upClip.isHidden = !shown.contains(.network)
        downClip.isHidden = !shown.contains(.network)

        for (metric, x) in segmentOrigins() {
            let icon = iconRect(at: x)
            switch metric {
            case .cpu:
                place(fanLayer, in: icon)
                fanLayer.path = fanPath(size: icon.size)
            case .memory:
                // A butt-capped line as thick as the bar fills it via strokeEnd.
                let inner = chipBody(icon).insetBy(dx: 2, dy: 2)
                place(memoryLayer, in: inner)
                let bar = CGMutablePath()
                bar.move(to: CGPoint(x: 0, y: inner.height / 2))
                bar.addLine(to: CGPoint(x: inner.width, y: inner.height / 2))
                memoryLayer.path = bar
                memoryLayer.lineWidth = inner.height
            case .disk:
                // Same trick for the pie: a circle stroked as wide as its radius.
                place(diskLayer, in: icon)
                let radius = pieRadius(icon) / 2
                let pie = CGMutablePath()
                pie.addArc(center: CGPoint(x: icon.width / 2, y: icon.height / 2), radius: radius,
                           startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi, clockwise: true)
                diskLayer.path = pie
                diskLayer.lineWidth = radius * 2
            case .network:
                let rects = arrowRects(at: x)
                upClip.frame = rects.up
                downClip.frame = rects.down
                upArrows.frame = upClip.bounds
                downArrows.frame = downClip.bounds
                upArrows.path = arrowsPath(size: rects.up.size, up: true)
                downArrows.path = arrowsPath(size: rects.down.size, up: false)
            }
        }
        CATransaction.commit()

        // Restart the loops so they use the new geometry.
        fanSpeed = -1
        upSpeed = -1
        downSpeed = -1
        updateAnimations()
    }

    /// Positions via bounds and position, since `frame` is undefined on a
    /// layer with a rotation transform.
    private func place(_ sublayer: CALayer, in rect: NSRect) {
        sublayer.bounds = CGRect(origin: .zero, size: rect.size)
        sublayer.position = CGPoint(x: rect.midX, y: rect.midY)
    }

    private func pieRadius(_ icon: NSRect) -> CGFloat {
        icon.width / 2 - 2.5
    }

    private func applyColors() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let color = NSColor.labelColor.cgColor
            fanLayer.fillColor = color
            memoryLayer.strokeColor = color
            diskLayer.strokeColor = color
            upArrows.fillColor = color
            downArrows.fillColor = color
        }
        CATransaction.commit()
    }

    // MARK: - Paths

    /// Three blades and a hub around the center of the icon.
    private func fanPath(size: CGSize) -> CGPath {
        let path = CGMutablePath()
        let r = size.width / 2 - 2
        for i in 0..<3 {
            let transform = CGAffineTransform(translationX: size.width / 2, y: size.height / 2)
                .rotated(by: CGFloat(i) * 2 * .pi / 3)
            path.move(to: .zero, transform: transform)
            path.addCurve(to: CGPoint(x: r, y: r * 0.25), control1: CGPoint(x: r * 0.15, y: r * 0.65),
                          control2: CGPoint(x: r * 0.85, y: r * 0.75), transform: transform)
            path.addCurve(to: .zero, control1: CGPoint(x: r * 1.05, y: -r * 0.2),
                          control2: CGPoint(x: r * 0.45, y: -r * 0.25), transform: transform)
            path.closeSubpath()
        }
        path.addEllipse(in: CGRect(x: size.width / 2 - 1.3, y: size.height / 2 - 1.3, width: 2.6, height: 2.6))
        return path
    }

    private func arrowPeriod(_ size: CGSize) -> CGFloat {
        size.height + 1.5
    }

    /// Three arrows one period apart, so the clip always shows a whole arrow
    /// while the layer slides through two periods.
    private func arrowsPath(size: CGSize, up: Bool) -> CGPath {
        let path = CGMutablePath()
        let head: CGFloat = 2.6
        let period = arrowPeriod(size)
        for i in 0..<3 {
            let r = CGRect(origin: CGPoint(x: 0, y: CGFloat(i) * period * (up ? -1 : 1)), size: size)
            if up {
                path.addLines(between: [CGPoint(x: r.minX, y: r.maxY - head), CGPoint(x: r.midX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY - head)])
                path.addRect(CGRect(x: r.midX - 0.6, y: r.minY, width: 1.2, height: r.height - head + 0.2))
            } else {
                path.addLines(between: [CGPoint(x: r.minX, y: r.minY + head), CGPoint(x: r.midX, y: r.minY), CGPoint(x: r.maxX, y: r.minY + head)])
                path.addRect(CGRect(x: r.midX - 0.6, y: r.minY + head - 0.2, width: 1.2, height: r.height - head + 0.2))
            }
        }
        return path
    }

    // MARK: - Drawing

    /// Static parts only: values, the fan ring, chip outline and the gauge tracks.
    override func draw(_ dirtyRect: NSRect) {
        guard !metrics.isEmpty, let context = NSGraphicsContext.current?.cgContext else { return }
        let color = NSColor.labelColor.cgColor
        context.setStrokeColor(color)
        context.setFillColor(color)
        context.setLineWidth(1)

        for (metric, x) in segmentOrigins() {
            let icon = iconRect(at: x)
            let valueX = x + Self.iconSize + Self.iconGap
            switch metric {
            case .cpu:
                context.strokeEllipse(in: icon.insetBy(dx: 0.5, dy: 0.5))
                drawValue(context, .cpu, cpu.map(Format.percent) ?? "-", x: valueX)
            case .memory:
                let body = chipBody(icon)
                context.addPath(CGPath(roundedRect: body, cornerWidth: 1.2, cornerHeight: 1.2, transform: nil))
                context.strokePath()
                for i in 0..<4 {
                    let pinX = body.minX + 2 + CGFloat(i) * 2.6
                    context.fill(CGRect(x: pinX, y: body.maxY, width: 1.1, height: 1.6))
                    context.fill(CGRect(x: pinX, y: body.minY - 1.6, width: 1.1, height: 1.6))
                }
                context.setAlpha(0.25)
                context.fill(body.insetBy(dx: 2, dy: 2))
                context.setAlpha(1)
                drawValue(context, .memory, memory.map(Format.percent) ?? "-", x: valueX)
            case .disk:
                context.strokeEllipse(in: icon.insetBy(dx: 0.5, dy: 0.5))
                let radius = pieRadius(icon)
                context.setAlpha(0.25)
                context.fillEllipse(in: CGRect(x: icon.midX - radius, y: icon.midY - radius, width: radius * 2, height: radius * 2))
                context.setAlpha(1)
                drawValue(context, .disk, disk.map(Format.percent) ?? "-", x: valueX)
            case .network:
                let rects = arrowRects(at: x)
                drawSmall(context, .up, upload.map(Format.compactSpeed) ?? "-", x: x, baseline: rects.up.minY)
                drawSmall(context, .down, download.map(Format.compactSpeed) ?? "-", x: x, baseline: rects.down.minY)
            }
        }
    }

    private func line(_ slot: Slot, _ text: String, _ font: NSFont) -> CTLine {
        if let cached = lines[slot], cached.text == text { return cached.line }
        let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        let line = CTLineCreateWithAttributedString(string)
        lines[slot] = (text, line)
        return line
    }

    private func drawValue(_ context: CGContext, _ slot: Slot, _ text: String, x: CGFloat) {
        let line = line(slot, text, Self.font)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        let y = ((bounds.height - ascent - descent) / 2 + descent).rounded()
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
    }

    private func drawSmall(_ context: CGContext, _ slot: Slot, _ text: String, x: CGFloat, baseline: CGFloat) {
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: x, y: baseline)
        CTLineDraw(line(slot, text, Self.smallFont), context)
    }

    // MARK: - Animation

    private var canAnimate: Bool {
        animationsEnabled && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func isActive(_ rate: Double?) -> Bool {
        (rate ?? 0) >= Self.activeRate
    }

    private func clamped(_ value: Double?) -> CGFloat {
        CGFloat(min(max(value ?? 0, 0), 1))
    }

    private func updateAnimations() {
        let animate = canAnimate
        // Up to ~1.6 turns per second at full load, still below 3% load.
        let load = cpu ?? 0
        let turns = animate && load >= 0.03 ? max((load * 16).rounded() / 10, 0.1) : 0
        if turns != fanSpeed {
            fanSpeed = turns
            loop(fanLayer, keyPath: "transform.rotation.z", distance: -2 * .pi, speed: turns)
        }

        let up = animate ? flowSpeed(upload) : 0
        if up != upSpeed {
            upSpeed = up
            loop(upArrows, keyPath: "transform.translation.y", distance: arrowPeriod(upClip.bounds.size), speed: up)
        }
        let down = animate ? flowSpeed(download) : 0
        if down != downSpeed {
            downSpeed = down
            loop(downArrows, keyPath: "transform.translation.y", distance: -arrowPeriod(downClip.bounds.size), speed: down)
        }
    }

    /// Flow speed grows with the logarithm of the rate, from ~0.8 to ~2.8
    /// cycles per second, rounded so small changes keep the running animation.
    private func flowSpeed(_ rate: Double?) -> Double {
        guard let rate, isActive(rate) else { return 0 }
        let speed = 0.8 + min(log10(rate / Self.activeRate), 4) * 0.5
        return (speed * 2).rounded() / 2
    }

    /// Repeats a move of `distance` along `keyPath` forever, continuing from
    /// wherever the layer currently is so a speed change does not jump.
    /// Zero speed stops it in place (rotation) or resets it (translation).
    private func loop(_ target: CALayer, keyPath: String, distance: CGFloat, speed: Double) {
        let isRotation = keyPath.hasSuffix("rotation.z")
        var current = (target.presentation()?.value(forKeyPath: keyPath) as? CGFloat) ?? 0
        current = current.truncatingRemainder(dividingBy: abs(distance))
        if speed == 0, !isRotation { current = 0 }

        target.removeAnimation(forKey: keyPath)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        target.setValue(current, forKeyPath: keyPath)
        CATransaction.commit()
        guard speed > 0 else { return }

        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = current
        animation.toValue = current + distance
        animation.duration = 1 / speed
        animation.repeatCount = .infinity
        target.add(animation, forKey: keyPath)
    }

    @objc private func displayOptionsDidChange() {
        updateAnimations()
    }
}
