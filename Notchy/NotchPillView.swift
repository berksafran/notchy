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

    private let shapeLayer = CAShapeLayer()
    private let earLayer   = CAShapeLayer()

    // MARK: Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds  = false
        layer?.backgroundColor = .clear

        shapeLayer.fillColor = NSColor.black.cgColor
        layer?.addSublayer(shapeLayer)

        earLayer.fillColor = NSColor.black.cgColor
        layer?.addSublayer(earLayer)
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

    private func updateShape() {
        let w = bounds.width
        let h = bounds.height
        guard w > 0, h > 0 else { return }

        shapeLayer.frame = CGRect(x: 0, y: 0, width: w, height: h)
        earLayer.isHidden = true

        shapeLayer.path = buildBodyPath(width: w, height: h)
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
    /// Returns the built-in display (the one with the notch), or the main screen as fallback.
    static var builtIn: NSScreen? {
        screens.first { screen in
            let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            return CGDisplayIsBuiltin(id) != 0
        } ?? main
    }
}
