import AppKit
import SwiftUI

// MARK: - NotchWindow

/// An invisible floating panel that sits behind the physical notch area.
///
/// Responsibilities:
/// - Detects notch dimensions on the built-in display
/// - Tracks mouse hover to grow/shrink in width
/// - Expands downward (bounces) when any session enters a non-idle state
/// - Hosts `NotchPillView` (custom drawn shape) and `NotchPillContent` (SwiftUI overlay)
class NotchWindow: NSPanel {

    // MARK: - Callbacks / configuration

    var onHover: (() -> Void)?
    /// Additional rects (in screen coordinates) that also trigger hover.
    var additionalHoverRects: [() -> NSRect] = []
    /// Used to keep the notch in hover-grown size while the panel is visible.
    var isPanelVisible: (() -> Bool)?
    /// Returns the current panel width so the hover state can match it exactly.
    var panelWidth: (() -> CGFloat)?

    // MARK: - Notch dimensions

    /// Physical notch width detected from auxiliary screen areas. Updated on screen change.
    private var notchWidth: CGFloat = 180
    /// The baseline notch bar height — set once on detection and NEVER changed afterwards.
    /// All animations keep the window height equal to this value.
    private var baseNotchHeight: CGFloat = 37

    // MARK: - State

    private var isExpanded = false
    private var isHovered  = false
    /// True while hoverGrow / hoverShrink animations are in flight.
    /// Prevents the polling timer from interrupting them with a competing width transition.
    private var isHoverTransitioning = false

    /// Prevents rapid expand/collapse cycling when terminal status flickers.
    private var collapseDebounceTimer: Timer?

    // MARK: - Subviews

    private let pillView = NotchPillView()
    private var pillContentHost: NSHostingView<NotchPillContent>?

    // MARK: - Animation

    private var activeDisplayLink: CVDisplayLinkWrapper?

    // MARK: - Event monitors

    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?

    // MARK: - Observers

    private var screenObserver: Any?
    private var statusObserver: Any?

    // MARK: - Init

    init(onHover: @escaping () -> Void) {
        self.onHover = onHover

        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        configureWindow()
        addSubviews()
        registerForDraggedTypes([.fileURL, .URL])

        detectNotchSize()
        positionAtNotch()
        orderFrontRegardless()
        setupMouseTracking()
        observeScreenChanges()
        observeStatusChanges()
    }

    private func configureWindow() {
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        hasShadow = false
        isOpaque = false
        animationBehavior = .none
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = false
        alphaValue = 1
    }

    private func addSubviews() {
        guard let cv = contentView else { return }

        cv.wantsLayer = true
        cv.layer?.masksToBounds = false

        pillView.frame = cv.bounds
        pillView.autoresizingMask = [.width, .height]
        cv.addSubview(pillView)

        let hostView = NSHostingView(rootView: NotchPillContent())
        hostView.frame = cv.bounds
        hostView.autoresizingMask = [.width, .height]
        hostView.wantsLayer = true
        hostView.layer?.backgroundColor = .clear
        cv.addSubview(hostView)
        pillContentHost = hostView
    }

    deinit {
        if let m = mouseMonitor       { NSEvent.removeMonitor(m) }
        if let m = localMouseMonitor  { NSEvent.removeMonitor(m) }
        if let o = screenObserver     { NotificationCenter.default.removeObserver(o) }
        if let o = statusObserver     { NotificationCenter.default.removeObserver(o) }
    }

    // MARK: - Drag destination (treat drag-over like hover)

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onHover?()
        return .generic
    }

    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .generic }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool { false }

    // MARK: - Notch size detection

    private func detectNotchSize() {
        guard let screen = NSScreen.builtIn else { return }

        if #available(macOS 12.0, *),
           let left  = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            notchWidth     = right.minX - left.maxX
            baseNotchHeight = screen.frame.maxY - min(left.minY, right.minY)
        } else {
            let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
            notchWidth      = 180
            baseNotchHeight = max(menuBarHeight, 25)
        }
    }

    // MARK: - Positioning

    private func positionAtNotch() {
        guard let screen = NSScreen.builtIn else { return }
        let sf = screen.frame
        let w  = currentTargetWidth()
        setFrame(NSRect(x: sf.midX - w / 2, y: sf.maxY - baseNotchHeight,
                        width: w, height: baseNotchHeight), display: true)
    }

    /// Called when the panel layout changes externally (e.g. screen resolution switch).
    func layoutDidChange() {
        isHovered = false
        positionAtNotch()
    }

    /// Called when the panel hides — forces the notch back to normal (un-hovered) size.
    func endHover() {
        guard isHovered else { return }
        isHovered = false
        hoverShrink()
    }

    /// Forces the notch into hovered (or un-hovered) state without waiting for a mouse event.
    /// Used to re-sync appearance after system dialogs that steal key focus.
    func forceHoverState(_ hovered: Bool) {
        guard hovered != isHovered else { return }
        isHovered = hovered
        if hovered {
            hoverGrow()
        } else {
            hoverShrink()
        }
    }

    // MARK: - Expand / Collapse

    private func observeStatusChanges() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NotchyNotchStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if !self.isExpanded {
                self.updateExpansionState()
            } else {
                // Debounce to prevent rapid cycling during brief state flickers
                self.collapseDebounceTimer?.invalidate()
                self.collapseDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
                    guard let self, self.isExpanded else { return }
                    self.collapseDebounceTimer = nil
                    self.updateExpansionState()
                }
            }
        }

        // Polling fallback to catch status changes that slip through the notification
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.updateExpansionState()
        }
    }

    private func updateExpansionState() {
        let shouldExpand = NotchDisplayState.current != .idle

        switch (shouldExpand, isExpanded) {
        case (true, false):
            collapseDebounceTimer?.invalidate()
            collapseDebounceTimer = nil
            expandWithBounce()

        case (false, true):
            guard collapseDebounceTimer == nil else { return }
            collapseDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.collapseDebounceTimer = nil
                if NotchDisplayState.current == .idle && self.isExpanded {
                    self.collapse()
                }
            }

        case (true, true):
            // Already expanded — cancel any pending collapse and check if width changed.
            // Skip if a hover animation is currently in flight to avoid competing transitions.
            collapseDebounceTimer?.invalidate()
            collapseDebounceTimer = nil
            guard !isHoverTransitioning else { break }
            let targetWidth = currentTargetWidth()
            if abs(frame.width - targetWidth) > 1 {
                animateWidthTransition(to: targetWidth)
            }

        default:
            break
        }
    }

    // MARK: - Expansion animations

    private func expandWithBounce() {
        isExpanded = true
        guard let screen = NSScreen.builtIn else { return }

        var targetFrame = centeredFrame(width: currentTargetWidth(), screen: screen)
        if isHovered { targetFrame = applyHoverGrow(to: targetFrame) }

        pillView.alphaValue       = 1
        pillContentHost?.alphaValue = 1

        animateFrame(to: targetFrame, duration: 0.35, easing: Self.easeInOut)
    }

    private func collapse() {
        isExpanded = false

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            if !self.isHovered {
                self.pillContentHost?.animator().alphaValue = 0
            }
        }

        guard let screen = NSScreen.builtIn else { return }
        var targetFrame = centeredFrame(width: currentTargetWidth(forExpanded: false), screen: screen)
        if isHovered { targetFrame = applyHoverGrow(to: targetFrame) }

        animateFrame(to: targetFrame, duration: 0.3, easing: Self.easeInOut, completion: { [weak self] in
            self?.pillContentHost?.alphaValue = 1
        })
    }

    private func animateWidthTransition(to targetWidth: CGFloat) {
        guard let screen = NSScreen.builtIn else { return }
        let targetFrame = NSRect(
            x: screen.frame.midX - targetWidth / 2,
            y: frame.origin.y,
            width: targetWidth,
            height: frame.height
        )

        let startFrame  = frame
        let startTime   = CACurrentMediaTime()
        let duration    = 0.3

        activeDisplayLink?.stop()
        activeDisplayLink = CVDisplayLinkWrapper { [weak self] in
            guard let self else { return false }
            let t    = min((CACurrentMediaTime() - startTime) / duration, 1.0)
            let ease = Self.easeInOut(t)
            let x    = startFrame.origin.x + (targetFrame.origin.x - startFrame.origin.x) * ease
            let w    = startFrame.width    + (targetFrame.width    - startFrame.width)    * ease
            DispatchQueue.main.async {
                self.setFrame(NSRect(x: x, y: self.frame.origin.y, width: w, height: self.frame.height), display: true)
            }
            return t < 1.0
        }
        activeDisplayLink?.start()
    }

    // MARK: - Hover grow / shrink

    /// Extra hit-test clearance below the bar so the cursor is detected even with
    /// a small gap between the notch window and the panel. Does NOT affect window height.
    private static let hoverGrowY: CGFloat = 6

    /// Returns a frame that matches the panel width. Height is always `baseNotchHeight`.
    private func applyHoverGrow(to rect: NSRect) -> NSRect {
        guard let screen = NSScreen.builtIn else { return rect }
        let targetWidth = panelWidth?() ?? notchWidth + 160
        return NSRect(
            x: screen.frame.midX - targetWidth / 2,
            y: screen.frame.maxY - baseNotchHeight,
            width:  targetWidth,
            height: baseNotchHeight
        )
    }

    private func hoverGrow() {
        pillView.isHovered = true
        NotchPillModel.shared.isHovering = true
        isHoverTransitioning = true

        let targetFrame    = applyHoverGrow(to: frame)
        let targetProtrusion = NotchPillView.earRadius
        let startProtrusion  = pillView.earProtrusion

        animateFrame(to: targetFrame, duration: 0.25, easing: Self.easeInOut, perFrame: { [weak self] ease in
            DispatchQueue.main.async {
                self?.pillView.earProtrusion = startProtrusion + (targetProtrusion - startProtrusion) * ease
            }
        }, completion: { [weak self] in
            self?.isHoverTransitioning = false
        })
    }

    private func hoverShrink() {
        NotchPillModel.shared.isHovering = false
        pillView.isHovered = false
        isHoverTransitioning = true

        guard let screen = NSScreen.builtIn else { return }
        let w = currentTargetWidth(forHovered: false)
        let targetFrame = NSRect(
            x: screen.frame.midX - w / 2,
            y: screen.frame.maxY - baseNotchHeight,
            width: w, height: baseNotchHeight
        )
        let startProtrusion = pillView.earProtrusion

        animateFrame(to: targetFrame, duration: 0.25, easing: Self.easeInOut, perFrame: { [weak self] ease in
            DispatchQueue.main.async {
                self?.pillView.earProtrusion = startProtrusion * (1.0 - ease)
            }
        }, completion: { [weak self] in
            self?.pillView.isHovered = false
            self?.isHoverTransitioning = false
        })
    }

    // MARK: - Mouse tracking

    private func setupMouseTracking() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            self?.checkMouse()
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.checkMouse()
            return event
        }
    }

    private func checkMouse() {
        guard let screen = NSScreen.builtIn else { return }
        let mouse = NSEvent.mouseLocation
        let w = currentTargetWidth()

        // Use hoverGrowY for hit-testing only — window height stays at baseNotchHeight
        let hitHeight = isHovered ? baseNotchHeight + Self.hoverGrowY : baseNotchHeight
        let notchRect = NSRect(
            x: screen.frame.midX - w / 2,
            y: screen.frame.maxY - hitHeight,
            width:  w,
            height: hitHeight + 1   // +1 ensures the top screen edge is inside the rect
        )

        let mouseInNotch      = notchRect.contains(mouse)
        let mouseInAdditional = additionalHoverRects.contains { $0().contains(mouse) }

        if mouseInNotch || mouseInAdditional {
            if !isHovered {
                isHovered = true
                hoverGrow()
            }
            if SettingsManager.shared.revealOnHover { onHover?() }
            return
        }

        if isHovered {
            let panelShowing = isPanelVisible?() ?? false
            if !panelShowing {
                isHovered = false
                hoverShrink()
            }
        }
    }

    // MARK: - Screen change observer

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.detectNotchSize()
            self?.positionAtNotch()
        }
    }

    // MARK: - NSWindow overrides

    override var canBecomeKey: Bool  { false }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        onHover?()
    }

    // MARK: - Private helpers

    /// Width to use based on hover / expansion state.
    private func currentTargetWidth(forHovered hovered: Bool? = nil, forExpanded expanded: Bool? = nil) -> CGFloat {
        let hovering = hovered ?? isHovered
        if hovering {
            return panelWidth?() ?? notchWidth + 160
        }
        return notchWidth * 1.5
    }

    /// A frame centered on screen at the notch Y position with `baseNotchHeight`.
    private func centeredFrame(width: CGFloat, screen: NSScreen) -> NSRect {
        NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - baseNotchHeight,
            width:  width,
            height: baseNotchHeight
        )
    }

    /// Animates from the current frame to `targetFrame` over `duration` seconds.
    /// - `perFrame`: Called with the current interpolation factor (0…1) on the display link thread.
    /// - `completion`: Called on the main thread once the animation finishes.
    private func animateFrame(
        to targetFrame: NSRect,
        duration: Double,
        easing: @escaping (Double) -> Double,
        perFrame: ((Double) -> Void)? = nil,
        completion: (() -> Void)? = nil
    ) {
        let startFrame = frame
        let startTime  = CACurrentMediaTime()

        activeDisplayLink?.stop()
        activeDisplayLink = CVDisplayLinkWrapper { [weak self] in
            guard let self else { return false }
            let t    = min((CACurrentMediaTime() - startTime) / duration, 1.0)
            let ease = easing(t)

            let x = startFrame.origin.x + (targetFrame.origin.x - startFrame.origin.x) * ease
            let y = startFrame.origin.y + (targetFrame.origin.y - startFrame.origin.y) * ease
            let w = startFrame.width    + (targetFrame.width    - startFrame.width)    * ease
            let h = self.baseNotchHeight    // Height is always pinned

            perFrame?(ease)

            DispatchQueue.main.async {
                self.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
                if t >= 1.0 { completion?() }
            }
            return t < 1.0
        }
        activeDisplayLink?.start()
    }

    /// Cubic ease-in-out. Marked `nonisolated` so it can be called from display link
    /// callbacks without triggering main-actor warnings.
    nonisolated private static func easeInOut(_ t: Double) -> Double {
        t < 0.5
            ? 4.0 * t * t * t
            : 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0
    }
}
