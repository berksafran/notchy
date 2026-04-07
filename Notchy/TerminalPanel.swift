import AppKit
import SwiftUI

// MARK: - ClickThroughHostingView

/// An `NSHostingView` that accepts first-mouse events so the panel responds
/// to clicks without requiring a prior activation click.
class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - TerminalPanel

/// The main floating panel that hosts the terminal and settings UI.
///
/// Key behaviours:
/// - Appears below the notch / status item with an expand animation
/// - Hides with a fade-up animation when it loses focus (unless pinned)
/// - Supports collapsing to tab-bar-only height via `NotchyToggleExpand`
/// - Accepts `Cmd+S` (checkpoint) and `Cmd+T` (new session) key shortcuts
class TerminalPanel: NSPanel {

    // MARK: Constants

    private static let collapsedHeight: CGFloat = 44

    // MARK: State

    private let sessionStore: SessionStore
    /// Saved full-height used to restore when expanding after a collapse.
    private var expandedHeight: CGFloat = 500

    // MARK: Init

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 864, height: 480),
            styleMask: [.borderless, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        configureWindow()

        let content = PanelContentView(sessionStore: sessionStore, onClose: { [weak self] in self?.hidePanel() })
        self.contentView = ClickThroughHostingView(rootView: content)

        registerNotifications()
    }

    private func configureWindow() {
        isFloatingPanel = true
        level = .floating
        isMovableByWindowBackground = true
        isMovable = true
        backgroundColor = .clear
        hasShadow = true
        isOpaque = false
        animationBehavior = .none
        hidesOnDeactivate = false
        minSize = NSSize(width: 660, height: 480)
    }

    private func registerNotifications() {
        let center = NotificationCenter.default

        center.addObserver(self, selector: #selector(windowDidResignKey),
                           name: NSWindow.didResignKeyNotification, object: self)
        center.addObserver(self, selector: #selector(windowDidBecomeKey),
                           name: NSWindow.didBecomeKeyNotification, object: self)
        center.addObserver(self, selector: #selector(handleHidePanel),
                           name: .NotchyHidePanel, object: nil)
        center.addObserver(self, selector: #selector(handleExpandPanel),
                           name: .NotchyExpandPanel, object: nil)
        center.addObserver(self, selector: #selector(handleToggleExpandNotification),
                           name: .NotchyToggleExpand, object: nil)
    }

    // MARK: - Show / Hide

    /// Shows the panel expanding outward from `midX` of the given `anchor` rect.
    func showPanel(below anchor: NSRect) {
        guard let screen = NSScreen.main else { return }
        showPanel(centeredAt: anchor.midX, screen: screen)
    }

    /// Shows the panel expanding outward from the horizontal centre of `screen`.
    func showPanelCentered(on screen: NSScreen) {
        showPanel(centeredAt: screen.frame.midX, screen: screen)
    }

    /// Core show implementation — eliminates duplicated code from the two public entry-points.
    private func showPanel(centeredAt midX: CGFloat, screen: NSScreen) {
        let notchH = notchHeight(for: screen)
        let finalY = screen.frame.maxY - notchH - frame.height + 2  // +2 overlaps the NotchWindow by 2pt to close the seam
        let targetX = midX - frame.width / 2

        if isVisible {
            setFrameOrigin(NSPoint(x: targetX, y: finalY))
            makeKeyAndOrderFront(nil)
        } else {
            animateIn(centeredAt: midX, finalX: targetX, finalY: finalY, screen: screen)
        }
        NotificationCenter.default.post(name: .NotchyNotchStatusChanged, object: nil)
    }

    /// Fly-in animation: starts at notch width, expands to full panel width.
    private func animateIn(centeredAt midX: CGFloat, finalX: CGFloat, finalY: CGFloat, screen: NSScreen) {
        // Capture dimensions BEFORE calling setFrame — setFrame will overwrite frame.width/height.
        let panelWidth  = frame.width
        let panelHeight = frame.height

        let startWidth = physicalNotchWidth(for: screen)
        let startX     = midX - startWidth / 2

        alphaValue = 0
        setFrame(NSRect(x: startX, y: finalY, width: startWidth, height: panelHeight), display: true)
        makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().alphaValue = 1
            animator().setFrame(NSRect(x: finalX, y: finalY, width: panelWidth, height: panelHeight), display: true)
        }
    }

    func hidePanel() {
        guard isVisible else { return }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
            animator().setFrameOrigin(NSPoint(x: frame.origin.x, y: frame.origin.y + 20))
        }) { [weak self] in
            self?.orderOut(nil)
        }
    }

    // MARK: - Expand / Collapse

    private func toggleExpand() {
        updateOpacity()
        if sessionStore.isTerminalExpanded {
            restoreExpandedHeight()
        } else {
            collapseToTabBar()
        }
    }

    private func restoreExpandedHeight() {
        var newFrame = frame
        newFrame.origin.y   -= expandedHeight - frame.height
        newFrame.size.height = expandedHeight
        minSize = NSSize(width: 480, height: 300)
        setFrame(newFrame, display: true, animate: false)
    }

    private func collapseToTabBar() {
        expandedHeight       = frame.height
        var newFrame         = frame
        newFrame.origin.y   += frame.height - Self.collapsedHeight
        newFrame.size.height = Self.collapsedHeight
        minSize = NSSize(width: 480, height: Self.collapsedHeight)
        setFrame(newFrame, display: true, animate: false)
    }

    // MARK: - Opacity

    private func updateOpacity() {
        let dimmed = !sessionStore.isTerminalExpanded && !isKeyWindow
        alphaValue      = dimmed ? 0.8 : 1.0
        backgroundColor = .clear
    }

    // MARK: - Notification handlers

    @objc private func handleHidePanel() { hidePanel() }

    @objc private func handleExpandPanel() { toggleExpand() }

    @objc private func handleToggleExpandNotification() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            toggleExpand()
        }
    }

    // MARK: - Window delegate

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        sessionStore.panelDidBecomeKey()
        updateOpacity()
    }

    @objc private func windowDidResignKey(_ notification: Notification) {
        if !sessionStore.isPinned && !sessionStore.isShowingDialog
            && attachedSheet == nil && (childWindows?.isEmpty ?? true) {
            hidePanel()
        }
        updateOpacity()
    }

    // MARK: - Event overrides

    /// Re-sends the first left-click so SwiftUI controls process it even when
    /// the panel wasn't focused (first click normally just activates the window).
    override func sendEvent(_ event: NSEvent) {
        let wasKey = isKeyWindow
        super.sendEvent(event)
        if !wasKey && event.type == .leftMouseDown {
            super.sendEvent(event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "s":
                sessionStore.createCheckpointForActiveSession()
                return true
            case "t":
                sessionStore.createQuickSession()
                return true
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    override var canBecomeKey: Bool  { true }
    override var canBecomeMain: Bool { true }

    // MARK: - Geometry helpers

    /// Height of the physical notch (or menu bar) on the given screen.
    private func notchHeight(for screen: NSScreen) -> CGFloat {
        if #available(macOS 12.0, *),
           let left  = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            return screen.frame.maxY - min(left.minY, right.minY)
        }
        return screen.frame.maxY - screen.visibleFrame.maxY
    }

    /// Width of the physical notch on the given screen (fallback: 180 pt).
    private func physicalNotchWidth(for screen: NSScreen) -> CGFloat {
        if #available(macOS 12.0, *),
           let left  = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            return right.minX - left.maxX
        }
        return 180
    }
}
