import Foundation
import AppKit
import QuartzCore

// MARK: - Plan A skin
// Visual-only layer. No scanner, deletion, navigation, permission, or task behavior lives here.
enum LegacyTheme {
    // Deep blue-black background from the approved Plan A visual.
    static let backgroundTop = NSColor(calibratedRed: 0.031, green: 0.062, blue: 0.098, alpha: 1.0)
    static let backgroundBottom = NSColor(calibratedRed: 0.014, green: 0.028, blue: 0.047, alpha: 1.0)

    static let sidebarTop = NSColor(calibratedRed: 0.033, green: 0.055, blue: 0.086, alpha: 1.0)
    static let sidebarBottom = NSColor(calibratedRed: 0.018, green: 0.031, blue: 0.050, alpha: 1.0)

    static let surfaceTop = NSColor(calibratedRed: 0.082, green: 0.115, blue: 0.165, alpha: 0.98)
    static let surfaceBottom = NSColor(calibratedRed: 0.052, green: 0.078, blue: 0.118, alpha: 0.99)

    static let table = NSColor(calibratedRed: 0.028, green: 0.048, blue: 0.074, alpha: 1.0)
    static let border = NSColor(calibratedWhite: 1.0, alpha: 0.075)
    static let borderStrong = NSColor(calibratedRed: 0.53, green: 0.34, blue: 1.0, alpha: 0.34)

    static let text = NSColor(calibratedRed: 0.965, green: 0.976, blue: 0.996, alpha: 1.0)
    static let textSecondary = NSColor(calibratedRed: 0.76, green: 0.80, blue: 0.86, alpha: 1.0)
    static let textMuted = NSColor(calibratedRed: 0.47, green: 0.53, blue: 0.61, alpha: 1.0)

    static let accent = NSColor(calibratedRed: 0.20, green: 0.65, blue: 1.0, alpha: 1.0)
    static let accentBlue2 = NSColor(calibratedRed: 0.23, green: 0.80, blue: 1.0, alpha: 1.0)
    static let accentPurple = NSColor(calibratedRed: 0.53, green: 0.32, blue: 1.0, alpha: 1.0)
    static let violet = NSColor(calibratedRed: 0.66, green: 0.31, blue: 1.0, alpha: 1.0)
    static let teal = NSColor(calibratedRed: 0.20, green: 0.78, blue: 0.76, alpha: 1.0)
    static let coral = NSColor(calibratedRed: 0.95, green: 0.43, blue: 0.23, alpha: 1.0)
    static let green = NSColor(calibratedRed: 0.27, green: 0.86, blue: 0.50, alpha: 1.0)
    static let orange = NSColor(calibratedRed: 0.98, green: 0.61, blue: 0.25, alpha: 1.0)

    static func iconColor(for modeKey: String) -> NSColor {
        switch modeKey {
        case "junk": return accentPurple
        case "large": return accent
        case "apps": return teal
        case "leftovers": return coral
        default: return accent
        }
    }

    static func iconBackground(for modeKey: String, selected: Bool, hover: Bool) -> NSColor {
        let c = iconColor(for: modeKey)
        if selected {
            return c.withAlphaComponent(0.96)
        }
        if hover {
            return c.withAlphaComponent(0.34)
        }
        return c.withAlphaComponent(0.24)
    }
}

final class LegacyGradientView: NSView {
    private let gradientLayer = CAGradientLayer()

    init(
        colors: [NSColor],
        startPoint: CGPoint = CGPoint(x: 0, y: 1),
        endPoint: CGPoint = CGPoint(x: 1, y: 0)
    ) {
        super.init(frame: .zero)
        wantsLayer = true
        gradientLayer.colors = colors.map { $0.cgColor }
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
        layer?.insertSublayer(gradientLayer, at: 0)
    }

    required init?(coder: NSCoder) { return nil }

    override func layout() {
        super.layout()
        gradientLayer.frame = bounds
    }
}

final class LegacyFeatureButton: NSButton {
    let modeKey: String
    private let iconKind: String
    private let titleText: String
    private let subtitleText: String
    private var hover = false
    private var pressed = false
    private var tracking: NSTrackingArea?

    init(modeKey: String, icon: String, title: String, subtitle: String) {
        self.modeKey = modeKey
        self.iconKind = icon
        self.titleText = title
        self.subtitleText = subtitle

        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.borderWidth = 1
        layer?.shadowColor = LegacyTheme.accentPurple.cgColor
        layer?.shadowOffset = CGSize(width: 0, height: 6)
        focusRingType = .none
        bezelStyle = .regularSquare
        setButtonType(.momentaryChange)
        applyAppearance(selected: false, animated: false)
    }

    required init?(coder: NSCoder) { return nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = tracking { removeTrackingArea(area) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        hover = true
        if state != .on {
            applyAppearance(selected: false, animated: true)
        } else {
            applyAppearance(selected: true, animated: true)
        }
    }

    override func mouseExited(with event: NSEvent) {
        hover = false
        if !pressed {
            applyAppearance(selected: state == .on, animated: true)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }

        pressed = true
        applyAppearance(selected: state == .on, animated: true)
        super.mouseDown(with: event)
        pressed = false
        applyAppearance(selected: state == .on, animated: true)
    }

    func setSelected(_ selected: Bool, animated: Bool) {
        state = selected ? .on : .off
        applyAppearance(selected: selected, animated: animated)
    }

    override func draw(_ dirtyRect: NSRect) {
        let selected = state == .on
        let iconRect = NSRect(x: 14, y: bounds.midY - 18, width: 36, height: 36)

        let iconBG = LegacyTheme.iconBackground(
            for: modeKey,
            selected: selected,
            hover: hover
        )

        iconBG.setFill()
        NSBezierPath(roundedRect: iconRect, xRadius: 11, yRadius: 11).fill()

        drawIcon(
            kind: iconKind,
            in: iconRect.insetBy(dx: 8, dy: 8),
            color: selected ? .white : LegacyTheme.iconColor(for: modeKey)
        )

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13.5, weight: .semibold),
            .foregroundColor: LegacyTheme.text
        ]

        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
            .foregroundColor: LegacyTheme.textSecondary
        ]

        titleText.draw(
            at: NSPoint(x: 62, y: bounds.midY + 3),
            withAttributes: titleAttrs
        )
        subtitleText.draw(
            at: NSPoint(x: 62, y: bounds.midY - 15),
            withAttributes: subtitleAttrs
        )
    }

    private func drawIcon(kind: String, in rect: NSRect, color: NSColor) {
        color.setStroke()
        color.setFill()

        if kind == "spark" {
            let p = NSBezierPath()
            p.move(to: NSPoint(x: rect.midX, y: rect.maxY))
            p.line(to: NSPoint(x: rect.midX + 2.6, y: rect.midY + 2.6))
            p.line(to: NSPoint(x: rect.maxX, y: rect.midY))
            p.line(to: NSPoint(x: rect.midX + 2.6, y: rect.midY - 2.6))
            p.line(to: NSPoint(x: rect.midX, y: rect.minY))
            p.line(to: NSPoint(x: rect.midX - 2.6, y: rect.midY - 2.6))
            p.line(to: NSPoint(x: rect.minX, y: rect.midY))
            p.line(to: NSPoint(x: rect.midX - 2.6, y: rect.midY + 2.6))
            p.close()
            p.fill()

        } else if kind == "file" {
            // Folder-like icon, matching the approved blue large-file tile.
            let body = NSBezierPath(
                roundedRect: NSRect(
                    x: rect.minX + 1,
                    y: rect.minY + 2,
                    width: rect.width - 2,
                    height: rect.height - 7
                ),
                xRadius: 2.5,
                yRadius: 2.5
            )
            body.lineWidth = 1.8
            body.stroke()

            let tab = NSBezierPath()
            tab.move(to: NSPoint(x: rect.minX + 3, y: rect.maxY - 6))
            tab.line(to: NSPoint(x: rect.midX - 1, y: rect.maxY - 6))
            tab.line(to: NSPoint(x: rect.midX + 2, y: rect.maxY - 3))
            tab.lineWidth = 1.8
            tab.lineJoinStyle = .round
            tab.stroke()

        } else if kind == "broom" {
            // Plan A uses a teal trash-can glyph for application uninstall.
            let lid = NSBezierPath()
            lid.move(to: NSPoint(x: rect.minX + 3, y: rect.maxY - 5))
            lid.line(to: NSPoint(x: rect.maxX - 3, y: rect.maxY - 5))
            lid.lineWidth = 1.8
            lid.lineCapStyle = .round
            lid.stroke()

            let handle = NSBezierPath()
            handle.move(to: NSPoint(x: rect.midX - 3, y: rect.maxY - 2))
            handle.line(to: NSPoint(x: rect.midX + 3, y: rect.maxY - 2))
            handle.lineWidth = 1.8
            handle.lineCapStyle = .round
            handle.stroke()

            let can = NSBezierPath(
                roundedRect: NSRect(
                    x: rect.minX + 5,
                    y: rect.minY + 2,
                    width: rect.width - 10,
                    height: rect.height - 8
                ),
                xRadius: 2,
                yRadius: 2
            )
            can.lineWidth = 1.8
            can.stroke()

            let slot1 = NSBezierPath()
            slot1.move(to: NSPoint(x: rect.midX - 3, y: rect.minY + 5))
            slot1.line(to: NSPoint(x: rect.midX - 3, y: rect.maxY - 9))
            slot1.move(to: NSPoint(x: rect.midX + 3, y: rect.minY + 5))
            slot1.line(to: NSPoint(x: rect.midX + 3, y: rect.maxY - 9))
            slot1.lineWidth = 1.3
            slot1.stroke()

        } else {
            // Orange magnifier for application leftovers.
            let ring = NSBezierPath(
                ovalIn: NSRect(
                    x: rect.minX + 1,
                    y: rect.midY - 1,
                    width: rect.width - 8,
                    height: rect.height - 8
                )
            )
            ring.lineWidth = 1.8
            ring.stroke()

            let handle = NSBezierPath()
            handle.move(to: NSPoint(x: rect.midX + 3, y: rect.midY - 2))
            handle.line(to: NSPoint(x: rect.maxX - 1, y: rect.minY + 1))
            handle.lineWidth = 2
            handle.lineCapStyle = .round
            handle.stroke()
        }
    }

    private func applyAppearance(selected: Bool, animated: Bool) {
        let bg: NSColor
        let border: NSColor
        let shadow: Float

        if pressed {
            bg = NSColor(calibratedRed: 0.105, green: 0.125, blue: 0.205, alpha: 1.0)
            border = LegacyTheme.iconColor(for: modeKey).withAlphaComponent(0.72)
            shadow = 0.18
        } else if selected {
            bg = NSColor(calibratedRed: 0.095, green: 0.105, blue: 0.225, alpha: 0.99)
            border = NSColor(calibratedRed: 0.56, green: 0.34, blue: 1.0, alpha: 0.60)
            shadow = 0.18
        } else if hover {
            bg = NSColor(calibratedRed: 0.075, green: 0.105, blue: 0.155, alpha: 0.96)
            border = LegacyTheme.iconColor(for: modeKey).withAlphaComponent(0.34)
            shadow = 0.08
        } else {
            bg = NSColor(calibratedRed: 0.056, green: 0.080, blue: 0.118, alpha: 0.82)
            border = LegacyTheme.border
            shadow = 0.0
        }

        // Keep Swift 5.2 closure capture semantics explicit.
        let isPressed = self.pressed

        let apply = {
            self.layer?.backgroundColor = bg.cgColor
            self.layer?.borderColor = border.cgColor
            self.layer?.shadowOpacity = shadow
            self.layer?.shadowRadius = selected ? 16 : 10
            self.layer?.transform = isPressed
                ? CATransform3DMakeScale(0.985, 0.985, 1)
                : CATransform3DIdentity
            self.needsDisplay = true
        }

        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.16
                apply()
            }, completionHandler: nil)
        } else {
            apply()
        }
    }
}

final class LegacyBadgeView: NSView {
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        layer?.cornerRadius = 11
        layer?.backgroundColor = LegacyTheme.accentPurple.withAlphaComponent(0.18).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = LegacyTheme.accentPurple.withAlphaComponent(0.30).cgColor

        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = NSColor(calibratedRed: 0.69, green: 0.58, blue: 1.0, alpha: 1.0)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(
            NSLayoutConstraint.Priority(rawValue: 1),
            for: .horizontal
        )
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        setContentCompressionResistancePriority(
            NSLayoutConstraint.Priority(rawValue: 1),
            for: .horizontal
        )
        setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) { return nil }

    func setText(_ text: String) {
        label.stringValue = text
    }
}

final class LegacyMetricCard: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "—")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let gradient = CAGradientLayer()

    init(title: String, subtitle: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        layer?.cornerRadius = 15
        layer?.borderWidth = 1
        layer?.borderColor = LegacyTheme.border.cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.26
        layer?.shadowRadius = 18
        layer?.shadowOffset = CGSize(width: 0, height: 8)

        gradient.colors = [
            LegacyTheme.surfaceTop.cgColor,
            LegacyTheme.surfaceBottom.cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        gradient.cornerRadius = 15
        layer?.insertSublayer(gradient, at: 0)

        titleLabel.stringValue = title
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = LegacyTheme.textSecondary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 21, weight: .semibold)
        valueLabel.textColor = LegacyTheme.text
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.stringValue = subtitle
        subtitleLabel.font = NSFont.systemFont(ofSize: 10.5)
        subtitleLabel.textColor = LegacyTheme.textMuted
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(subtitleLabel)

        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 11),

            valueLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 3),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10),

            heightAnchor.constraint(equalToConstant: 80)
        ])
    }

    required init?(coder: NSCoder) { return nil }

    override func layout() {
        super.layout()
        gradient.frame = bounds
    }

    func update(value: String, subtitle: String? = nil, animated: Bool = true) {
        if let s = subtitle {
            subtitleLabel.stringValue = s
        }

        if animated && value != valueLabel.stringValue {
            valueLabel.alphaValue = 0.35
            valueLabel.stringValue = value
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.18
                self.valueLabel.animator().alphaValue = 1.0
            }, completionHandler: nil)
        } else {
            valueLabel.stringValue = value
        }
    }
}

final class LegacyScanPulseView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.backgroundColor = LegacyTheme.accent.cgColor
        layer?.shadowColor = LegacyTheme.accent.cgColor
        layer?.shadowOpacity = 0.45
        layer?.shadowRadius = 7
    }

    required init?(coder: NSCoder) { return nil }

    func start() {
        isHidden = false
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.30
        pulse.duration = 0.65
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        layer?.add(pulse, forKey: "scanPulse")
    }

    func stop() {
        layer?.removeAnimation(forKey: "scanPulse")
        isHidden = true
    }
}

final class LegacyProgressBar: NSView {
    private let trackLayer = CALayer()
    private let fillLayer = CAGradientLayer()
    private var currentProgress: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        layer?.cornerRadius = 4
        layer?.masksToBounds = false
        layer?.backgroundColor = NSColor.clear.cgColor

        trackLayer.cornerRadius = 4
        trackLayer.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.11).cgColor
        layer?.addSublayer(trackLayer)

        fillLayer.cornerRadius = 4
        fillLayer.colors = [
            LegacyTheme.accent.cgColor,
            LegacyTheme.accentBlue2.cgColor
        ]
        fillLayer.startPoint = CGPoint(x: 0, y: 0.5)
        fillLayer.endPoint = CGPoint(x: 1, y: 0.5)
        fillLayer.shadowColor = LegacyTheme.accent.cgColor
        fillLayer.shadowOpacity = 0.42
        fillLayer.shadowRadius = 7
        fillLayer.shadowOffset = .zero
        layer?.addSublayer(fillLayer)

        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) { return nil }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 120, height: 8)
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackLayer.frame = bounds
        let clamped = max(0, min(1, currentProgress))
        let width = max(bounds.height, bounds.width * clamped)
        fillLayer.frame = NSRect(x: 0, y: 0, width: width, height: bounds.height)
        CATransaction.commit()
    }

    func setProgress(_ value: Double, animated: Bool) {
        let clamped = CGFloat(max(0, min(1, value)))

        if abs(clamped - currentProgress) < 0.0001 {
            return
        }

        let oldProgress = currentProgress
        currentProgress = clamped

        let oldWidth = max(bounds.height, bounds.width * oldProgress)
        let targetWidth = max(bounds.height, bounds.width * clamped)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fillLayer.frame = NSRect(
            x: 0,
            y: 0,
            width: targetWidth,
            height: bounds.height
        )
        CATransaction.commit()

        if animated && bounds.width > 0 {
            let anim = CABasicAnimation(keyPath: "bounds.size.width")
            anim.fromValue = fillLayer.presentation()?.bounds.width ?? oldWidth
            anim.toValue = targetWidth
            anim.duration = 0.18
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            fillLayer.add(anim, forKey: "progressWidth")
        }
    }
}

final class LegacyProminentButton: NSButton {
    private var hover = false
    private var pressed = false
    private var tracking: NSTrackingArea?
    private let gradient = CAGradientLayer()
    private let titleLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 17
        layer?.masksToBounds = false
        focusRingType = .none
        bezelStyle = .regularSquare
        setButtonType(.momentaryChange)

        gradient.cornerRadius = 17
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        layer?.insertSublayer(gradient, at: 0)

        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateTitle()
        updateStyle()
    }

    required init?(coder: NSCoder) { return nil }

    override var title: String {
        didSet {
            updateTitle()
            invalidateIntrinsicContentSize()
            needsLayout = true
        }
    }

    override var intrinsicContentSize: NSSize {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold)
        ]
        let width = title.size(withAttributes: attrs).width
        return NSSize(width: max(210, width + 64), height: 54)
    }

    override func layout() {
        super.layout()
        gradient.frame = bounds
    }

    override func draw(_ dirtyRect: NSRect) {
        // Custom layer + centered text only. Avoid duplicate NSButtonCell title.
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = tracking { removeTrackingArea(area) }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        hover = true
        updateStyle()
    }

    override func mouseExited(with event: NSEvent) {
        hover = false
        if !pressed {
            updateStyle()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }

        pressed = true
        updateStyle()
        super.mouseDown(with: event)
        pressed = false
        updateStyle()
    }

    override var isEnabled: Bool {
        didSet {
            alphaValue = isEnabled ? 1.0 : 0.58
        }
    }

    func pulse() {
        let anim = CABasicAnimation(keyPath: "transform.scale")
        anim.fromValue = 1.0
        anim.toValue = 1.035
        anim.duration = 0.17
        anim.autoreverses = true
        anim.repeatCount = 1
        layer?.add(anim, forKey: "pulse")
    }

    private func updateTitle() {
        titleLabel.stringValue = title
    }

    private func updateStyle() {
        if pressed {
            gradient.colors = [
                NSColor(calibratedRed: 0.13, green: 0.50, blue: 0.88, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.16, green: 0.66, blue: 0.94, alpha: 1).cgColor
            ]
            layer?.shadowOpacity = 0.18
            layer?.shadowRadius = 10
            layer?.transform = CATransform3DMakeScale(0.975, 0.975, 1)
        } else if hover {
            gradient.colors = [
                NSColor(calibratedRed: 0.20, green: 0.70, blue: 1.0, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.26, green: 0.82, blue: 1.0, alpha: 1).cgColor
            ]
            layer?.shadowOpacity = 0.40
            layer?.shadowRadius = 20
            layer?.transform = CATransform3DIdentity
        } else {
            gradient.colors = [
                LegacyTheme.accent.cgColor,
                LegacyTheme.accentBlue2.cgColor
            ]
            layer?.shadowOpacity = 0.30
            layer?.shadowRadius = 17
            layer?.transform = CATransform3DIdentity
        }

        layer?.shadowColor = LegacyTheme.accent.cgColor
        layer?.shadowOffset = CGSize(width: 0, height: 7)
    }
}

final class LegacySecondaryButton: NSButton {
    private var hover = false
    private var pressed = false
    private var tracking: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        wantsLayer = true

        layer?.cornerRadius = 13
        layer?.borderWidth = 1

        focusRingType = .none
        bezelStyle = .regularSquare
        font = NSFont.systemFont(ofSize: 13, weight: .medium)
        contentTintColor = LegacyTheme.text
        updateStyle()
    }

    required init?(coder: NSCoder) { return nil }

    override var intrinsicContentSize: NSSize {
        let s = super.intrinsicContentSize
        return NSSize(width: max(112, s.width + 26), height: 42)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = tracking { removeTrackingArea(area) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        hover = true
        updateStyle()
    }

    override func mouseExited(with event: NSEvent) {
        hover = false
        if !pressed {
            updateStyle()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }

        pressed = true
        updateStyle()
        super.mouseDown(with: event)
        pressed = false
        updateStyle()
    }

    override var isEnabled: Bool {
        didSet {
            updateStyle()
        }
    }

    private func updateStyle() {
        if !isEnabled {
            alphaValue = 0.46
            layer?.backgroundColor = NSColor(calibratedRed: 0.055, green: 0.077, blue: 0.112, alpha: 0.72).cgColor
            layer?.borderColor = LegacyTheme.border.cgColor
            layer?.transform = CATransform3DIdentity
        } else if pressed {
            alphaValue = 1.0
            layer?.backgroundColor = NSColor(calibratedRed: 0.10, green: 0.21, blue: 0.34, alpha: 0.98).cgColor
            layer?.borderColor = LegacyTheme.accent.cgColor
            layer?.transform = CATransform3DMakeScale(0.97, 0.97, 1)
        } else if hover {
            alphaValue = 1.0
            layer?.backgroundColor = NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.19, alpha: 0.98).cgColor
            layer?.borderColor = LegacyTheme.accent.withAlphaComponent(0.45).cgColor
            layer?.transform = CATransform3DIdentity
        } else {
            alphaValue = 1.0
            layer?.backgroundColor = NSColor(calibratedRed: 0.055, green: 0.080, blue: 0.118, alpha: 0.88).cgColor
            layer?.borderColor = LegacyTheme.borderStrong.cgColor
            layer?.transform = CATransform3DIdentity
        }
    }
}

final class LegacyTextButton: NSButton {
    private var hover = false
    private var pressed = false
    private var tracking: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        wantsLayer = true

        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        focusRingType = .none
        bezelStyle = .regularSquare

        font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        contentTintColor = LegacyTheme.textSecondary
        updateStyle()
    }

    required init?(coder: NSCoder) { return nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = tracking { removeTrackingArea(area) }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        hover = true
        updateStyle()
    }

    override func mouseExited(with event: NSEvent) {
        hover = false
        if !pressed {
            updateStyle()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }

        pressed = true
        updateStyle()
        super.mouseDown(with: event)
        pressed = false
        updateStyle()
    }

    override var isEnabled: Bool {
        didSet { updateStyle() }
    }

    private func updateStyle() {
        if !isEnabled {
            alphaValue = 0.40
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.borderColor = NSColor.clear.cgColor
            layer?.transform = CATransform3DIdentity
        } else if pressed {
            alphaValue = 1.0
            layer?.backgroundColor = NSColor(calibratedRed: 0.11, green: 0.22, blue: 0.35, alpha: 0.96).cgColor
            layer?.borderColor = LegacyTheme.accent.cgColor
            layer?.transform = CATransform3DMakeScale(0.96, 0.96, 1)
        } else if hover {
            alphaValue = 1.0
            layer?.backgroundColor = NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.19, alpha: 0.92).cgColor
            layer?.borderColor = LegacyTheme.accent.withAlphaComponent(0.35).cgColor
            layer?.transform = CATransform3DIdentity
        } else {
            alphaValue = 1.0
            layer?.backgroundColor = NSColor(calibratedRed: 0.045, green: 0.068, blue: 0.102, alpha: 0.70).cgColor
            layer?.borderColor = LegacyTheme.border.cgColor
            layer?.transform = CATransform3DIdentity
        }
    }
}
