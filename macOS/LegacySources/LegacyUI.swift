import Foundation
import AppKit
import QuartzCore

enum LegacyTheme {
    static let backgroundTop = NSColor(calibratedRed: 0.026, green: 0.034, blue: 0.058, alpha: 1.0)
    static let backgroundBottom = NSColor(calibratedRed: 0.010, green: 0.014, blue: 0.027, alpha: 1.0)

    static let sidebarTop = NSColor(calibratedRed: 0.045, green: 0.055, blue: 0.086, alpha: 1.0)
    static let sidebarBottom = NSColor(calibratedRed: 0.019, green: 0.025, blue: 0.043, alpha: 1.0)

    static let surfaceTop = NSColor(calibratedRed: 0.075, green: 0.087, blue: 0.125, alpha: 0.96)
    static let surfaceBottom = NSColor(calibratedRed: 0.036, green: 0.043, blue: 0.069, alpha: 0.97)

    static let table = NSColor(calibratedRed: 0.030, green: 0.035, blue: 0.052, alpha: 1.0)
    static let border = NSColor(calibratedWhite: 1.0, alpha: 0.085)
    static let borderStrong = NSColor(calibratedRed: 0.49, green: 0.36, blue: 1.0, alpha: 0.28)

    static let text = NSColor(calibratedWhite: 0.98, alpha: 1.0)
    static let textSecondary = NSColor(calibratedWhite: 0.73, alpha: 1.0)
    static let textMuted = NSColor(calibratedWhite: 0.48, alpha: 1.0)

    static let accent = NSColor(calibratedRed: 0.19, green: 0.55, blue: 1.0, alpha: 1.0)
    static let accentPurple = NSColor(calibratedRed: 0.62, green: 0.25, blue: 1.0, alpha: 1.0)
    static let violet = NSColor(calibratedRed: 0.75, green: 0.33, blue: 1.0, alpha: 1.0)
    static let green = NSColor(calibratedRed: 0.27, green: 0.82, blue: 0.51, alpha: 1.0)
    static let orange = NSColor(calibratedRed: 1.0, green: 0.66, blue: 0.20, alpha: 1.0)
}

final class LegacyGradientView: NSView {
    private let gradientLayer = CAGradientLayer()

    init(colors: [NSColor], startPoint: CGPoint = CGPoint(x: 0, y: 1), endPoint: CGPoint = CGPoint(x: 1, y: 0)) {
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
        }
    }

    override func mouseExited(with event: NSEvent) {
        hover = false
        if state != .on && !pressed {
            applyAppearance(selected: false, animated: true)
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

        let iconBG = selected
            ? LegacyTheme.accent
            : NSColor(calibratedWhite: 1.0, alpha: hover ? 0.11 : 0.075)

        iconBG.setFill()
        NSBezierPath(roundedRect: iconRect, xRadius: 11, yRadius: 11).fill()

        drawIcon(
            kind: iconKind,
            in: iconRect.insetBy(dx: 8, dy: 8),
            color: selected ? .white : LegacyTheme.accent
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
            let r = rect.insetBy(dx: 2, dy: 1)
            let p = NSBezierPath(roundedRect: r, xRadius: 2.5, yRadius: 2.5)
            p.lineWidth = 1.8
            p.stroke()

            let line = NSBezierPath()
            line.move(to: NSPoint(x: r.minX + 3, y: r.midY + 2))
            line.line(to: NSPoint(x: r.maxX - 3, y: r.midY + 2))
            line.move(to: NSPoint(x: r.minX + 3, y: r.midY - 3))
            line.line(to: NSPoint(x: r.maxX - 6, y: r.midY - 3))
            line.lineWidth = 1.5
            line.stroke()
        } else if kind == "broom" {
            let handle = NSBezierPath()
            handle.move(to: NSPoint(x: rect.minX + 5, y: rect.maxY - 1))
            handle.line(to: NSPoint(x: rect.midX + 1, y: rect.midY - 1))
            handle.lineWidth = 2.2
            handle.lineCapStyle = .round
            handle.stroke()

            let head = NSBezierPath()
            head.move(to: NSPoint(x: rect.midX - 1, y: rect.midY))
            head.line(to: NSPoint(x: rect.maxX, y: rect.minY + 3))
            head.line(to: NSPoint(x: rect.maxX - 5, y: rect.minY))
            head.line(to: NSPoint(x: rect.midX - 4, y: rect.midY - 3))
            head.close()
            head.fill()
        } else {
            let p = NSBezierPath(
                roundedRect: rect.insetBy(dx: 2, dy: 2),
                xRadius: 3,
                yRadius: 3
            )
            p.lineWidth = 1.8
            p.stroke()

            let dot = NSBezierPath(
                ovalIn: NSRect(
                    x: rect.midX - 2,
                    y: rect.midY - 2,
                    width: 4,
                    height: 4
                )
            )
            dot.fill()
        }
    }

    private func applyAppearance(selected: Bool, animated: Bool) {
        let bg: NSColor
        let border: NSColor
        let shadow: Float

        if pressed {
            bg = NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.22, alpha: 1.0)
            border = NSColor(calibratedRed: 0.66, green: 0.43, blue: 1.0, alpha: 0.72)
            shadow = 0.20
        } else if selected {
            bg = NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.23, alpha: 0.98)
            border = NSColor(calibratedRed: 0.58, green: 0.34, blue: 1.0, alpha: 0.58)
            shadow = 0.18
        } else if hover {
            bg = NSColor(calibratedWhite: 1.0, alpha: 0.075)
            border = LegacyTheme.borderStrong
            shadow = 0.10
        } else {
            bg = NSColor(calibratedWhite: 1.0, alpha: 0.035)
            border = LegacyTheme.border
            shadow = 0.0
        }

        // Swift 5.2 requires instance properties captured by closures
        // to use explicit self capture semantics. Snapshot the property
        // before creating the closure so this also builds on older toolchains.
        let isPressed = self.pressed

        let apply = {
            self.layer?.backgroundColor = bg.cgColor
            self.layer?.borderColor = border.cgColor
            self.layer?.shadowColor = LegacyTheme.accentPurple.cgColor
            self.layer?.shadowOpacity = shadow
            self.layer?.shadowRadius = selected ? 16 : 10
            self.layer?.shadowOffset = CGSize(width: 0, height: 5)
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
        layer?.backgroundColor = NSColor(
            calibratedRed: 0.14,
            green: 0.30,
            blue: 0.56,
            alpha: 0.34
        ).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(
            calibratedRed: 0.28,
            green: 0.56,
            blue: 1.0,
            alpha: 0.13
        ).cgColor

        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = LegacyTheme.accent
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
        layer?.shadowOpacity = 0.22
        layer?.shadowRadius = 18
        layer?.shadowOffset = CGSize(width: 0, height: 7)

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
    }

    required init?(coder: NSCoder) { return nil }

    func start() {
        isHidden = false
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.25
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
        trackLayer.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        layer?.addSublayer(trackLayer)

        fillLayer.cornerRadius = 4
        fillLayer.colors = [LegacyTheme.accent.cgColor, LegacyTheme.accentPurple.cgColor]
        fillLayer.startPoint = CGPoint(x: 0, y: 0.5)
        fillLayer.endPoint = CGPoint(x: 1, y: 0.5)
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

        // Most callbacks carry the same phase percentage. Re-animating an
        // identical width hundreds of times caused the progress bar to shimmer.
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
        // Intentionally do not call super.draw(_:)
        // The native NSButtonCell would otherwise draw `title` a second time
        // underneath our centered titleLabel, which caused the visible overlap.
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
            alphaValue = isEnabled ? 1.0 : 0.72
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
                NSColor(calibratedRed: 0.13, green: 0.43, blue: 0.86, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.45, green: 0.28, blue: 0.85, alpha: 1).cgColor
            ]
            layer?.shadowOpacity = 0.16
            layer?.shadowRadius = 10
            layer?.transform = CATransform3DMakeScale(0.975, 0.975, 1)
        } else if hover {
            gradient.colors = [
                NSColor(calibratedRed: 0.18, green: 0.60, blue: 1.0, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.53, green: 0.39, blue: 1.0, alpha: 1).cgColor
            ]
            layer?.shadowOpacity = 0.34
            layer?.shadowRadius = 20
            layer?.transform = CATransform3DIdentity
        } else {
            gradient.colors = [
                LegacyTheme.accent.cgColor,
                LegacyTheme.accentPurple.cgColor
            ]
            layer?.shadowOpacity = 0.24
            layer?.shadowRadius = 16
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
            alphaValue = 0.48
            layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.035).cgColor
            layer?.borderColor = LegacyTheme.border.cgColor
            layer?.transform = CATransform3DIdentity
        } else if pressed {
            alphaValue = 1.0
            layer?.backgroundColor = NSColor(calibratedRed: 0.16, green: 0.22, blue: 0.36, alpha: 0.96).cgColor
            layer?.borderColor = LegacyTheme.accent.cgColor
            layer?.transform = CATransform3DMakeScale(0.97, 0.97, 1)
        } else if hover {
            alphaValue = 1.0
            layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.095).cgColor
            layer?.borderColor = LegacyTheme.borderStrong.cgColor
            layer?.transform = CATransform3DIdentity
        } else {
            alphaValue = 1.0
            layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.055).cgColor
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
            layer?.backgroundColor = NSColor(calibratedRed: 0.18, green: 0.25, blue: 0.42, alpha: 0.94).cgColor
            layer?.borderColor = LegacyTheme.accent.cgColor
            layer?.transform = CATransform3DMakeScale(0.96, 0.96, 1)
        } else if hover {
            alphaValue = 1.0
            layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.075).cgColor
            layer?.borderColor = LegacyTheme.borderStrong.cgColor
            layer?.transform = CATransform3DIdentity
        } else {
            alphaValue = 1.0
            layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.025).cgColor
            layer?.borderColor = LegacyTheme.border.cgColor
            layer?.transform = CATransform3DIdentity
        }
    }
}
