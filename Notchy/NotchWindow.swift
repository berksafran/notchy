import AppKit
import SwiftUI

/// An invisible window that sits behind the notch area.
/// When the mouse hovers over the notch or any additional hover rect, it fires a callback to show the main panel.
/// Expands downward with a bounce animation when any session is working.
class NotchWindow: NSPanel {
    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var screenObserver: Any?
    private var statusObserver: Any?
    var onHover: (() -> Void)?
    /// Additional rects (in screen coordinates) that should also trigger hover.
    /// Each closure is called at check-time so the rect stays up-to-date.
    var additionalHoverRects: [() -> NSRect] = []
    /// Closure to check if the main panel is currently visible.
    /// When the panel is visible, the notch stays in hover-grown size.
    var isPanelVisible: (() -> Bool)?
    /// Returns the current width of the main panel, used to match the notch hover width.
    var panelWidth: (() -> CGFloat)?

    /// Detected notch dimensions (updated on screen change).
    private var notchWidth: CGFloat = 180
    private var notchHeight: CGFloat = 37

    /// Whether the notch is currently expanded (wider, for working state)
    private var isExpanded = false

    /// Debounce timer for collapsing — prevents rapid expand/collapse cycling
    /// when terminal status flickers between .working and .idle.
    private var collapseDebounceTimer: Timer?

    /// Whether the mouse is currently hovering over the notch
    private var isHovered = false
    /// The pill-shaped background view shown when expanded
    private let pillView = NotchPillView()

    /// SwiftUI content overlay shown inside the pill when expanded
    private var pillContentHost: NSHostingView<NotchPillContent>?
    
    private var activeDisplayLink: CVDisplayLinkWrapper?

    init(onHover: @escaping () -> Void) {
        self.onHover = onHover

        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

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

        // Set up the pill view (always visible)
        if let cv = contentView {
            pillView.frame = cv.bounds
            pillView.autoresizingMask = [.width, .height]
            pillView.alphaValue = 1
            cv.addSubview(pillView)
            cv.wantsLayer = true
            cv.layer?.masksToBounds = false

            // SwiftUI content overlay inside the pill
            let hostView = NSHostingView(rootView: NotchPillContent())
            hostView.frame = cv.bounds
            hostView.autoresizingMask = [.width, .height]
            hostView.alphaValue = 1
            hostView.wantsLayer = true
            hostView.layer?.backgroundColor = .clear
            cv.addSubview(hostView)
            pillContentHost = hostView
        }

        // Accept file drags so hovering a dragged file over the notch opens the panel
        registerForDraggedTypes([.fileURL, .URL])

        detectNotchSize()
        positionAtNotch()
        orderFrontRegardless()
        setupTracking()
        observeScreenChanges()
        observeStatusChanges()
    }

    // MARK: - Drag destination (treat drag-over like hover)

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onHover?()
        return .generic
    }

    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .generic
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        // We don't actually accept the drop — just trigger the hover
        return false
    }

    deinit {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Expand / Collapse

    private func observeStatusChanges() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NotchyNotchStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if !(self?.isExpanded ?? false) {
                self?.updateExpansionState()
            }
            else {
                self?.collapseDebounceTimer?.invalidate()
                self?.collapseDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
                    guard let self, self.isExpanded else { return }
                    self.collapseDebounceTimer = nil
                    self.updateExpansionState()
                }
            }
        }
        // Also poll on a timer to catch status changes from the observation timer
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.updateExpansionState()
        }
    }

    private func updateExpansionState() {
        let shouldExpand = NotchDisplayState.current != .idle

        if shouldExpand && !isExpanded {
            collapseDebounceTimer?.invalidate()
            collapseDebounceTimer = nil
            expandWithBounce()
        } else if !shouldExpand && isExpanded {
            // Debounce collapse to avoid rapid cycling when terminal status
            // flickers between .working and .idle during transitions.
            guard collapseDebounceTimer == nil else { return }
            collapseDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.collapseDebounceTimer = nil
                // Re-check — state may have changed during the debounce
                if NotchDisplayState.current == .idle && self.isExpanded {
                    self.collapse()
                }
            }
        } else if shouldExpand && isExpanded {
            // Still expanded and should be — cancel any pending collapse
            collapseDebounceTimer?.invalidate()
            collapseDebounceTimer = nil
        }
    }

    private func expandWithBounce() {
        isExpanded = true
        guard let screen = NSScreen.builtIn else { return }
        let screenFrame = screen.frame

        let targetWidth: CGFloat = panelWidth?() ?? notchWidth + 160
        var targetFrame = NSRect(
            x: screenFrame.midX - targetWidth / 2,
            y: screenFrame.maxY - notchHeight,
            width: targetWidth,
            height: notchHeight
        )
        if isHovered {
            targetFrame = applyHoverGrow(to: targetFrame)
        }

        // Show pill view and content
        pillView.alphaValue = 1
        pillContentHost?.alphaValue = 1

        // Bounce animation using display link
        let startFrame = frame
        let startTime = CACurrentMediaTime()
        let duration: Double = 0.35

        activeDisplayLink?.stop()
        let displayLink = CVDisplayLinkWrapper { [weak self] in
            guard let self else { return false }
            let elapsed = CACurrentMediaTime() - startTime
            let t = min(elapsed / duration, 1.0)

            // Ease in-out
            let ease = Self.easeInOut(t)

            let currentX = startFrame.origin.x + (targetFrame.origin.x - startFrame.origin.x) * ease
            let currentY = startFrame.origin.y + (targetFrame.origin.y - startFrame.origin.y) * ease
            let currentWidth = startFrame.width + (targetFrame.width - startFrame.width) * ease
            let currentHeight = startFrame.height + (targetFrame.height - startFrame.height) * ease

            DispatchQueue.main.async {
                self.setFrame(
                    NSRect(x: currentX, y: currentY, width: currentWidth, height: currentHeight),
                    display: true
                )
            }
            return t < 1.0
        }
        activeDisplayLink = displayLink
        displayLink.start()
    }

    private func collapse() {
        isExpanded = false

        // Fade out the status content only if not currently hovered
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            if !self.isHovered {
                self.pillContentHost?.animator().alphaValue = 0
            }
        }

        guard let screen = NSScreen.builtIn else { return }
        let screenFrame = screen.frame

        var targetFrame = NSRect(
            x: screenFrame.midX - notchWidth / 2,
            y: screenFrame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )
        if isHovered {
            targetFrame = applyHoverGrow(to: targetFrame)
        }

        let startFrame = frame
        let startTime = CACurrentMediaTime()
        let duration: Double = 0.3

        activeDisplayLink?.stop()
        let displayLink = CVDisplayLinkWrapper { [weak self] in
            guard let self else { return false }
            let elapsed = CACurrentMediaTime() - startTime
            let t = min(elapsed / duration, 1.0)

            // Ease in-out
            let ease = Self.easeInOut(t)

            let currentX = startFrame.origin.x + (targetFrame.origin.x - startFrame.origin.x) * ease
            let currentY = startFrame.origin.y + (targetFrame.origin.y - startFrame.origin.y) * ease
            let currentWidth = startFrame.width + (targetFrame.width - startFrame.width) * ease
            let currentHeight = startFrame.height + (targetFrame.height - startFrame.height) * ease

            DispatchQueue.main.async {
                self.setFrame(
                    NSRect(x: currentX, y: currentY, width: currentWidth, height: currentHeight),
                    display: true
                )
                if t >= 1.0 {
                    // Restore content once collapse animation finishes
                    self.pillContentHost?.alphaValue = 1
                }
            }
            return t < 1.0
        }
        activeDisplayLink = displayLink
        displayLink.start()
    }

    /// Ease in-out (cubic)
    private static func easeInOut(_ t: Double) -> Double {
        return t < 0.5
            ? 4.0 * t * t * t
            : 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0
    }

    // MARK: - Notch size detection

    private func detectNotchSize() {
        guard let screen = NSScreen.builtIn else { return }

        if #available(macOS 12.0, *),
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            // Notch spans the gap between the two auxiliary areas
            notchWidth = right.minX - left.maxX
            notchHeight = screen.frame.maxY - min(left.minY, right.minY)
        } else {
            // No notch (external display, older Mac) — use sensible defaults
            let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
            notchWidth = 180
            notchHeight = max(menuBarHeight, 25)
        }
    }

    // MARK: - Positioning

    private func positionAtNotch() {
        guard let screen = NSScreen.builtIn else { return }
        let screenFrame = screen.frame
        let baseWidth: CGFloat
        if isHovered {
            baseWidth = panelWidth?() ?? notchWidth + 160
        } else if isExpanded {
            baseWidth = panelWidth?() ?? notchWidth + 80
        } else {
            baseWidth = notchWidth * 1.5
        }
        let x = screenFrame.midX - baseWidth / 2
        let y = screenFrame.maxY - notchHeight
        setFrame(NSRect(x: x, y: y, width: baseWidth, height: notchHeight), display: true)
    }


    // MARK: - Mouse tracking

    private func setupTracking() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            self?.checkMouse()
        }
        // Local monitor catches events when the mouse is over this window itself
        // (global monitors only fire for events outside the app's windows)
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.checkMouse()
            return event
        }
    }

    private func checkMouse() {
        let mouseLocation = NSEvent.mouseLocation

        // Check the notch area itself
        guard let screen = NSScreen.builtIn else { return }
        let screenFrame = screen.frame
        
        let currentWidth: CGFloat
        if isHovered {
            currentWidth = panelWidth?() ?? notchWidth + 160
        } else if isExpanded {
            currentWidth = panelWidth?() ?? notchWidth + 80
        } else {
            currentWidth = notchWidth * 1.5
        }
        let currentHeight = isHovered ? notchHeight + Self.hoverGrowY : notchHeight
        
        let notchRect = NSRect(
            x: screenFrame.midX - currentWidth / 2,
            y: screenFrame.maxY - currentHeight,
            width: currentWidth,
            height: currentHeight + 1  // +1 so the top screen edge (maxY) is inside the rect
        )

        let mouseInNotch = notchRect.contains(mouseLocation)
        let mouseInAdditional = additionalHoverRects.contains { $0().contains(mouseLocation) }

        if mouseInNotch || mouseInAdditional {
            if !isHovered {
                isHovered = true
                hoverGrow()
            }
            
            // Only trigger panel reveal automatically if the setting is enabled
            if SettingsManager.shared.revealOnHover {
                onHover?()
            }
            return
        }

        if isHovered {
            // Keep hover-grown size while the panel is visible
            let panelShowing = isPanelVisible?() ?? false
            if !panelShowing {
                isHovered = false
                hoverShrink()
            }
        }
    }

    /// Re-positions the Hap.
    func layoutDidChange() {
        isHovered = false
        positionAtNotch()
    }

    /// Called when the panel hides — forces the notch back to normal size.
    func endHover() {
        guard isHovered else { return }
        isHovered = false
        hoverShrink()
    }

    // MARK: - Hover grow / shrink

    private static let hoverGrowY: CGFloat = 6 // Grow slightly downwards to bridge any gap with the panel

    /// Applies hover grow: expands the notch to match the panel width (or a sensible fallback).
    private func applyHoverGrow(to rect: NSRect) -> NSRect {
        guard let screen = NSScreen.builtIn else {
            return rect
        }
        let screenFrame = screen.frame
        let targetWidth = panelWidth?() ?? notchWidth + 160
        return NSRect(
            x: screenFrame.midX - targetWidth / 2,
            y: screenFrame.maxY - notchHeight - Self.hoverGrowY,
            width: targetWidth,
            height: notchHeight + Self.hoverGrowY
        )
    }

    private func hoverGrow() {
        pillView.isHovered = true
        NotchPillModel.shared.isHovering = true
        
        let startFrame = frame
        let targetFrame = applyHoverGrow(to: frame)

        let targetProtrusion = NotchPillView.earRadius
        let startProtrusion = pillView.earProtrusion
        
        let startTime = CACurrentMediaTime()
        let duration: Double = 0.25 // Smooth dynamic island style duration
        
        activeDisplayLink?.stop()
        let displayLink = CVDisplayLinkWrapper { [weak self] in
            guard let self else { return false }
            let elapsed = CACurrentMediaTime() - startTime
            let t = min(elapsed / duration, 1.0)
            let ease = Self.easeInOut(t)
            
            let protrusion = startProtrusion + (targetProtrusion - startProtrusion) * ease
            
            let currentX = startFrame.origin.x + (targetFrame.origin.x - startFrame.origin.x) * ease
            let currentY = startFrame.origin.y + (targetFrame.origin.y - startFrame.origin.y) * ease
            let currentWidth = startFrame.width + (targetFrame.width - startFrame.width) * ease
            let currentHeight = startFrame.height + (targetFrame.height - startFrame.height) * ease
            
            DispatchQueue.main.async {
                self.pillView.earProtrusion = protrusion
                self.setFrame(NSRect(x: currentX, y: currentY, width: currentWidth, height: currentHeight), display: true)
            }
            return t < 1.0
        }
        activeDisplayLink = displayLink
        displayLink.start()
    }

    private func hoverShrink() {
        NotchPillModel.shared.isHovering = false
        pillView.isHovered = false
        guard let screen = NSScreen.builtIn else { return }
        let screenFrame = screen.frame
        let baseWidth = isExpanded ? (panelWidth?() ?? notchWidth + 80) : notchWidth * 1.5
        let targetFrame = NSRect(
            x: screenFrame.midX - baseWidth / 2,
            y: screenFrame.maxY - notchHeight,
            width: baseWidth,
            height: notchHeight
        )
        
        let startFrame = frame
        let startProtrusion = pillView.earProtrusion
        
        let startTime = CACurrentMediaTime()
        let duration: Double = 0.25
        
        activeDisplayLink?.stop()
        let displayLink = CVDisplayLinkWrapper { [weak self] in
            guard let self else { return false }
            let elapsed = CACurrentMediaTime() - startTime
            let t = min(elapsed / duration, 1.0)
            let ease = Self.easeInOut(t)
            
            let protrusion = startProtrusion * (1.0 - ease)
            
            let currentX = startFrame.origin.x + (targetFrame.origin.x - startFrame.origin.x) * ease
            let currentY = startFrame.origin.y + (targetFrame.origin.y - startFrame.origin.y) * ease
            let currentWidth = startFrame.width + (targetFrame.width - startFrame.width) * ease
            let currentHeight = startFrame.height + (targetFrame.height - startFrame.height) * ease
            
            DispatchQueue.main.async {
                self.pillView.earProtrusion = protrusion
                self.setFrame(NSRect(x: currentX, y: currentY, width: currentWidth, height: currentHeight), display: true)
                if t >= 1.0 {
                    self.pillView.isHovered = false
                }
            }
            return t < 1.0
        }
        activeDisplayLink = displayLink
        displayLink.start()
    }

    // MARK: - Observers

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

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        // Trigger reveal on click
        onHover?()
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

// MARK: - Notch pill background view

class NotchPillView: NSView {
    var isHovered: Bool = false {
        didSet {
            if oldValue != isHovered {
                updateShape()
            }
        }
    }

    private let shapeLayer = CAShapeLayer()
    private let earLayer = CAShapeLayer()
    static let earRadius: CGFloat = 10

    /// Controls how far the ears protrude outward from the body (0 to earRadius).
    var earProtrusion: CGFloat = 0 {
        didSet { needsLayout = true }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.backgroundColor = .clear
        shapeLayer.fillColor = NSColor.black.cgColor
        layer?.addSublayer(shapeLayer)

        earLayer.fillColor = NSColor.black.cgColor
        layer?.addSublayer(earLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        updateShape()
    }

    private func updateShape() {
        let w = bounds.width
        let h = bounds.height
        guard w > 0, h > 0 else { return }

        shapeLayer.frame = CGRect(x: 0, y: 0, width: w, height: h)
        earLayer.isHidden = true

        let bodyPath = CGMutablePath()
        
        // Exact MacBook notch radii
        let topRadius: CGFloat = 8.0    // Concave shoulder radius (where it meets the bezel)
        let bottomRadius: CGFloat = isHovered ? 0.0 : 14.0

        // Start at top-left corner
        bodyPath.move(to: CGPoint(x: 0, y: h))

        // Top-left concave curve (Shoulder)
        bodyPath.addQuadCurve(
            to: CGPoint(x: topRadius, y: h - topRadius),
            control: CGPoint(x: topRadius, y: h)
        )

        // Left vertical edge to bottom-left corner
        bodyPath.addLine(to: CGPoint(x: topRadius, y: bottomRadius))

        if bottomRadius > 0 {
            // Bottom-left corner (Convex)
            bodyPath.addQuadCurve(
                to: CGPoint(x: topRadius + bottomRadius, y: 0),
                control: CGPoint(x: topRadius, y: 0)
            )
        } else {
            bodyPath.addLine(to: CGPoint(x: topRadius, y: 0))
        }

        // Bottom horizontal edge
        bodyPath.addLine(to: CGPoint(x: w - topRadius - bottomRadius, y: 0))

        if bottomRadius > 0 {
            // Bottom-right corner (Convex)
            bodyPath.addQuadCurve(
                to: CGPoint(x: w - topRadius, y: bottomRadius),
                control: CGPoint(x: w - topRadius, y: 0)
            )
        } else {
            bodyPath.addLine(to: CGPoint(x: w - topRadius, y: 0))
        }

        // Right vertical edge
        bodyPath.addLine(to: CGPoint(x: w - topRadius, y: h - topRadius))

        // Top-right concave curve (Shoulder)
        bodyPath.addQuadCurve(
            to: CGPoint(x: w, y: h),
            control: CGPoint(x: w - topRadius, y: h)
        )

        // Close path along the top screen edge
        bodyPath.addLine(to: CGPoint(x: 0, y: h))
        bodyPath.closeSubpath()
        
        shapeLayer.path = bodyPath
    }
}

// MARK: - Notch display state

enum NotchDisplayState: Equatable {
    case idle
    case working
    case waitingForInput
    case taskCompleted

    /// Hierarchy: .taskCompleted (always shown) > .waitingForInput > .working > .idle
    static var current: NotchDisplayState {
        guard SettingsManager.shared.claudeIntegrationEnabled else { return .idle }
        let sessions = SessionStore.shared.sessions
        if sessions.contains(where: { $0.terminalStatus == .taskCompleted }) {
            return .taskCompleted
        }
        if sessions.contains(where: { $0.terminalStatus == .waitingForInput }) {
            return .waitingForInput
        }
        if sessions.contains(where: { $0.terminalStatus == .working }) {
            return .working
        }
        return .idle
    }
}

// MARK: - Notch pill model (Observable for reliable SwiftUI reactivity)

@Observable
class NotchPillModel {
    static let shared = NotchPillModel()
    var isHovering: Bool = false
}

// MARK: - Notch pill SwiftUI content

struct NotchPillContent: View {
    // Access all @Observable singletons directly — same pattern as SessionStore.shared/SettingsManager.shared,
    // ensuring SwiftUI's withObservationTracking registers dependencies during body evaluation.
    private var pillModel = NotchPillModel.shared
    private var store = SessionStore.shared
    private var settings = SettingsManager.shared

    private var displayState: NotchDisplayState {
        guard settings.claudeIntegrationEnabled else { return .idle }
        if store.sessions.contains(where: { $0.terminalStatus == .taskCompleted }) { return .taskCompleted }
        if store.sessions.contains(where: { $0.terminalStatus == .waitingForInput }) { return .waitingForInput }
        if store.sessions.contains(where: { $0.terminalStatus == .working }) { return .working }
        return .idle
    }

    var body: some View {
        let isHovering = pillModel.isHovering
        ZStack {
            // Glow layer background
            if displayState != .idle {
                Circle()
                    .fill(glowColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                    .blur(radius: 20)
                    .transition(.opacity)
            }

            HStack(spacing: 0) {
                // MARK: - Left Side (Terminal, Settings)
                if isHovering {
                    HStack(spacing: 14) {
                        // Terminal Icon
                        Button(action: {
                            store.activeTab = .terminal
                            NotificationCenter.default.post(name: .NotchyExpandPanel, object: nil)
                        }) {
                            Image(systemName: "apple.terminal")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(store.activeTab == .terminal ? .accentColor : .white)
                        }
                        .buttonStyle(.plain)

                        // Settings Icon
                        Button(action: {
                            store.activeTab = .settings
                            NotificationCenter.default.post(name: .NotchyExpandPanel, object: nil)
                        }) {
                            Image(systemName: "gear")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(store.activeTab == .settings ? .accentColor : .white)
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }

                Spacer()

                // MARK: - Right Side (Status, Bot Face, Pin, Quit)
                HStack(spacing: 14) {
                    if displayState != .idle {
                        // Indicators (Status)
                        switch displayState {
                        case .taskCompleted:
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.green)
                        case .waitingForInput:
                            ReadyIndicatorView()
                                .frame(width: 14, height: 14)
                        case .working:
                            WorkingIndicatorView()
                                .frame(width: 14, height: 14)
                        case .idle:
                            EmptyView()
                        }
                        
                        // Bot Face (Moved to far right)
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 18, height: 18)
                            .overlay(alignment: .trailing) {
                                BotFaceView(state: displayState)
                                    .frame(width: 20, height: 15)
                                    .mask(RoundedRectangle(cornerRadius: 5))
                            }
                    } else if !isHovering && displayState == .idle {
                        Image(systemName: "eyes")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.orange)
                    }

                    if isHovering {
                        // Pin Icon
                        Button(action: { store.isPinned.toggle() }) {
                            Image(systemName: store.isPinned ? "pin.fill" : "pin")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)

                        // Quit Icon
                        Button(action: { NSApp.terminate(nil) }) {
                            Image(systemName: "power")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
            .padding(.horizontal, 16 + (isHovering ? 4 : 0))
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: displayState)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .offset(y: isHovering ? -3 : -2)
        .onChange(of: displayState) {
            NotificationCenter.default.post(name: .NotchyNotchStatusChanged, object: nil)
        }
    }

    private var glowColor: Color {
        switch displayState {
        case .working: return .yellow
        case .waitingForInput: return .green
        case .taskCompleted: return .green
        case .idle: return .clear
        }
    }
}

struct ReadyIndicatorView: View {
    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 10, height: 10)
    }
}

struct WorkingIndicatorView: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(Color.yellow)
            .frame(width: 10, height: 10)
            .opacity(isAnimating ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}

// MARK: - CVDisplayLink wrapper for smooth animation

/// Drives a frame-by-frame animation callback on the display refresh rate.
class CVDisplayLinkWrapper {
    private var displayLink: CVDisplayLink?
    private let callback: () -> Bool  // return true to keep running
    private var stopped = false

    init(callback: @escaping () -> Bool) {
        self.callback = callback
    }

    func start() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let displayLink else { return }

        let opaqueWrapper = Unmanaged.passRetained(self)
        CVDisplayLinkSetOutputCallback(displayLink, { (_, _, _, _, _, userInfo) -> CVReturn in
            guard let userInfo else { return kCVReturnError }
            let wrapper = Unmanaged<CVDisplayLinkWrapper>.fromOpaque(userInfo).takeUnretainedValue()
            guard !wrapper.stopped else { return kCVReturnSuccess }
            let keepRunning = wrapper.callback()
            if !keepRunning {
                // Stop immediately on this thread to prevent further callbacks
                wrapper.stopped = true
                if let link = wrapper.displayLink {
                    CVDisplayLinkStop(link)
                }
                // Release the retained reference on main
                DispatchQueue.main.async {
                    wrapper.displayLink = nil
                    Unmanaged<CVDisplayLinkWrapper>.fromOpaque(userInfo).release()
                }
            }
            return kCVReturnSuccess
        }, opaqueWrapper.toOpaque())

        CVDisplayLinkStart(displayLink)
    }

    func stop() {
        stopped = true
        guard let displayLink else { return }
        CVDisplayLinkStop(displayLink)
        self.displayLink = nil
    }
}

#Preview("Notch İçeriği") {
    NotchPillContent()
        .frame(width: 180, height: 37)
        .background(Color.black)
}
