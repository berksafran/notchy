import AppKit

// MARK: - Notch pill background view

/// The custom-drawn black pill shape rendered behind the notch window content.
///
/// Draws the exact MacBook notch silhouette — concave shoulders at the top,
/// rounded bottom corners when idle, flat bottom when hovered.
/// The `earProtrusion` property is animated to show/hide the "Dynamic Island"
/// style ear shapes during hover transitions.
class NotchPillView: NSView {

    // MARK: Properties

    var isHovered: Bool = false {
        didSet {
            guard oldValue != isHovered else { return }
            updateShape()
        }
    }

    /// How far the ears protrude outward from the body (animated 0 → `earRadius`).
    var earProtrusion: CGFloat = 0 {
        didSet { needsLayout = true }
    }

    static let earRadius: CGFloat = 10

    // MARK: Layers

    // MARK: Layers

    private let shapeLayer    = CAShapeLayer()
    private let gradientLayer = CAGradientLayer()
    private let earLayer      = CAShapeLayer()

    var displayState: NotchDisplayState = .idle {
        didSet {
            guard oldValue != displayState else { return }
            updateAppearance()
        }
    }

    // MARK: Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds  = false
        layer?.backgroundColor = .clear

        // Use shapeLayer as a mask for the gradient
        shapeLayer.fillColor = NSColor.white.cgColor // White = Opaque for mask
        // Anchor both layers to center so they grow equally in both directions
        shapeLayer.anchorPoint    = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        gradientLayer.mask = shapeLayer
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 0.5)
        layer?.addSublayer(gradientLayer)

        earLayer.fillColor = NSColor.black.cgColor
        layer?.addSublayer(earLayer)
        
        updateAppearance(animated: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Layout

    override func layout() {
        super.layout()
        updateShape()
    }

    // MARK: Drawing

    private func updateAppearance(animated: Bool = true) {
        let colors: [CGColor]
        if displayState == .idle {
            // Premium gradient for idle state
            colors = [
                NSColor.systemIndigo.cgColor,
                NSColor.systemPurple.cgColor
            ]
        } else {
            // Solid black for other states
            colors = [
                NSColor.black.cgColor,
                NSColor.black.cgColor
            ]
        }

        if animated {
            let anim = CABasicAnimation(keyPath: "colors")
            anim.fromValue = gradientLayer.colors
            anim.toValue = colors
            anim.duration = 0.4
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            gradientLayer.add(anim, forKey: "colorsChange")
        }
        gradientLayer.colors = colors
    }

    private func updateShape() {
        let w = bounds.width
        let h = bounds.height
        guard w > 0, h > 0 else { return }

        // Center both layers so they expand equally to left and right
        let centerX = bounds.midX
        let centerY = bounds.midY

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.bounds   = bounds
        gradientLayer.position = CGPoint(x: centerX, y: centerY)
        shapeLayer.bounds      = bounds
        shapeLayer.position    = CGPoint(x: centerX, y: centerY)
        CATransaction.commit()

        earLayer.isHidden = true
        shapeLayer.path   = buildBodyPath(width: w, height: h)
    }

    /// Builds the notch body path.
    ///
    /// - `topRadius`: Concave shoulder radius where the pill meets the screen bezel.
    /// - `bottomRadius`: Convex corner radius at the bottom (0 when hovered → flat bottom).
    private func buildBodyPath(width w: CGFloat, height h: CGFloat) -> CGPath {
        let topRadius: CGFloat    = 8.0
        let bottomRadius: CGFloat = isHovered ? 0.0 : 14.0

        let path = CGMutablePath()

        // Top-left corner
        path.move(to: CGPoint(x: 0, y: h))

        // Top-left concave shoulder
        path.addQuadCurve(
            to:      CGPoint(x: topRadius, y: h - topRadius),
            control: CGPoint(x: topRadius, y: h)
        )

        // Left edge → bottom-left corner
        path.addLine(to: CGPoint(x: topRadius, y: bottomRadius))
        if bottomRadius > 0 {
            path.addQuadCurve(
                to:      CGPoint(x: topRadius + bottomRadius, y: 0),
                control: CGPoint(x: topRadius, y: 0)
            )
        } else {
            path.addLine(to: CGPoint(x: topRadius, y: 0))
        }

        // Bottom edge
        path.addLine(to: CGPoint(x: w - topRadius - bottomRadius, y: 0))

        // Bottom-right corner
        if bottomRadius > 0 {
            path.addQuadCurve(
                to:      CGPoint(x: w - topRadius, y: bottomRadius),
                control: CGPoint(x: w - topRadius, y: 0)
            )
        } else {
            path.addLine(to: CGPoint(x: w - topRadius, y: 0))
        }

        // Right edge → top-right concave shoulder
        path.addLine(to: CGPoint(x: w - topRadius, y: h - topRadius))
        path.addQuadCurve(
            to:      CGPoint(x: w, y: h),
            control: CGPoint(x: w - topRadius, y: h)
        )

        // Close along the top screen edge
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()

        return path
    }
}

// MARK: - NSScreen helper

extension NSScreen {
    /// Returns the screen identified by the user's preference, or the built-in notch display as fallback.
    static var target: NSScreen? {
        if let preferredID = SettingsManager.shared.preferredScreenID,
           let preferredScreen = NSScreen.screens.first(where: { $0.displayID == preferredID }) {
            return preferredScreen
        }
        return builtIn
    }

    /// Returns the built-in display (the one with the notch), or the main screen as fallback.
    static var builtIn: NSScreen? {
        screens.first { $0.isBuiltIn } ?? main
    }

    var displayID: CGDirectDisplayID {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }

    var isBuiltIn: Bool {
        CGDisplayIsBuiltin(displayID) != 0
    }
}
