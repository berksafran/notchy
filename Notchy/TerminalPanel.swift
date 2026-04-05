import AppKit
import SwiftUI

class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

class TerminalPanel: NSPanel {
    private let sessionStore: SessionStore
    private static let collapsedHeight: CGFloat = 44
    private var expandedHeight: CGFloat = 500

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 864, height: 480),
            styleMask: [.borderless, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        level = .floating
        isMovableByWindowBackground = true // Allow dragging by header
        isMovable = true // Allow window to move
        backgroundColor = .clear
        hasShadow = true
        isOpaque = false
        animationBehavior = .none
        hidesOnDeactivate = false
        minSize = NSSize(width: 660, height: 480) // Increased by 20%

        let contentView = PanelContentView(
            sessionStore: sessionStore,
            onClose: { [weak self] in self?.hidePanel() }
        )
        let hosting = ClickThroughHostingView(rootView: contentView)
        self.contentView = hosting

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: self
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: self
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHidePanel),
            name: .NotchyHidePanel,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExpandPanel),
            name: .NotchyExpandPanel,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleExpandNotification),
            name: .NotchyToggleExpand,
            object: nil
        )
    }

    private func getNotchHeight(for screen: NSScreen) -> CGFloat {
        if #available(macOS 12.0, *),
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            return screen.frame.maxY - min(left.minY, right.minY)
        }
        return screen.frame.maxY - screen.visibleFrame.maxY
    }

    func showPanel(below rect: NSRect) {
        if let screen = NSScreen.main {
            let panelWidth = frame.width
            let panelHeight = frame.height
            let x = rect.midX - panelWidth / 2

            let notchHeight = getNotchHeight(for: screen)
            let isExpanded = SettingsManager.shared.layoutStyle == .expanded
            // Expanded: panel covers the notch area (top of panel = top of screen).
            // Classic: panel sits just below the notch with 8pt overlap to bridge the hover gap.
            let finalY = isExpanded
                ? screen.frame.maxY - panelHeight
                : screen.frame.maxY - notchHeight - panelHeight + 8

            if !isVisible {
                let notchHeight = getNotchHeight(for: screen)
                // Fiziksel notch varsa onun genişliğini al, yoksa standart 180 kullan
                var nw: CGFloat = 180
                if #available(macOS 12.0, *), 
                   let left = screen.auxiliaryTopLeftArea, 
                   let right = screen.auxiliaryTopRightArea {
                    nw = right.minX - left.maxX
                }

                // Notch genişliğinden başlayarak yana doğru açılma (expand) animasyonu
                let startWidth = isExpanded ? (panelWidth / 3) : nw
                let startX = rect.midX - startWidth / 2
                
                alphaValue = 0.0
                setFrame(NSRect(x: startX, y: finalY, width: startWidth, height: panelHeight), display: true)
                makeKeyAndOrderFront(nil)
                
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    animator().alphaValue = 1.0
                    animator().setFrame(NSRect(x: x, y: finalY, width: panelWidth, height: panelHeight), display: true)
                }
            } else {
                setFrameOrigin(NSPoint(x: x, y: finalY))
                makeKeyAndOrderFront(nil)
            }
        }
        NotificationCenter.default.post(name: .NotchyNotchStatusChanged, object: nil)
    }

    func showPanelCentered(on screen: NSScreen) {
        let screenFrame = screen.frame
        let panelWidth = frame.width
        let panelHeight = frame.height
        let x = screenFrame.midX - panelWidth / 2

        let notchHeight = getNotchHeight(for: screen)
        let isExpanded = SettingsManager.shared.layoutStyle == .expanded
        let finalY = isExpanded
            ? screenFrame.maxY - panelHeight
            : screenFrame.maxY - notchHeight - panelHeight + 8

        if !isVisible {
            let notchHeight = getNotchHeight(for: screen)
            // Fiziksel notch varsa onun genişliğini al, yoksa standart 180 kullan
            var nw: CGFloat = 180
            if #available(macOS 12.0, *), 
               let left = screen.auxiliaryTopLeftArea, 
               let right = screen.auxiliaryTopRightArea {
                nw = right.minX - left.maxX
            }

            // Notch genişliğinden başlayarak yana doğru açılma (expand) animasyonu
            let startWidth = isExpanded ? (panelWidth / 3) : nw
            let startX = screenFrame.midX - startWidth / 2
            
            alphaValue = 0.0
            setFrame(NSRect(x: startX, y: finalY, width: startWidth, height: panelHeight), display: true)
            makeKeyAndOrderFront(nil)
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animator().alphaValue = 1.0
                animator().setFrame(NSRect(x: x, y: finalY, width: panelWidth, height: panelHeight), display: true)
            }
        } else {
            setFrameOrigin(NSPoint(x: x, y: finalY))
            makeKeyAndOrderFront(nil)
        }
        NotificationCenter.default.post(name: .NotchyNotchStatusChanged, object: nil)
    }

    func hidePanel() {
        guard isVisible else { return }
        
        let startY = frame.origin.y
        let endY = startY + 20
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0.0
            animator().setFrameOrigin(NSPoint(x: frame.origin.x, y: endY))
        }) { [weak self] in
            self?.orderOut(nil)
        }
    }

    private func handleToggleExpand() {
        updateOpacity()
        if sessionStore.isTerminalExpanded {
            // Expanding: restore saved height, anchor top edge
            let newHeight = expandedHeight
            var newFrame = frame
            newFrame.origin.y -= (newHeight - frame.height)
            newFrame.size.height = newHeight
            minSize = NSSize(width: 480, height: 300)
            setFrame(newFrame, display: true, animate: false)
        } else {
            // Collapsing: save current height, shrink to tab bar only
            expandedHeight = frame.height
            let newHeight = Self.collapsedHeight
            var newFrame = frame
            newFrame.origin.y += (frame.height - newHeight)
            newFrame.size.height = newHeight
            minSize = NSSize(width: 480, height: Self.collapsedHeight)
            setFrame(newFrame, display: true, animate: false)
        }
    }

    @objc private func handleHidePanel() {
        hidePanel()
    }

    @objc private func handleExpandPanel() {
        handleToggleExpand()
    }

    @objc private func handleToggleExpandNotification() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            handleToggleExpand()
        }
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        sessionStore.panelDidBecomeKey()
        updateOpacity()
    }

    @objc private func windowDidResignKey(_ notification: Notification) {
        if !sessionStore.isPinned && !sessionStore.isShowingDialog && attachedSheet == nil && childWindows?.isEmpty ?? true {
            hidePanel()
        }
        updateOpacity()
    }

    private func updateOpacity() {
        let collapsed = !sessionStore.isTerminalExpanded
        let unfocused = !isKeyWindow
        // Collapsed + unfocused: dim the whole window
        alphaValue = (collapsed && unfocused) ? 0.8 : 1.0
        // Expanded + unfocused: clear window background so SwiftUI chrome
        // transparency shows through (terminal stays opaque via its own view)
        backgroundColor = .clear
    }

    override func sendEvent(_ event: NSEvent) {
        let wasKey = isKeyWindow
        super.sendEvent(event)
        // When the panel wasn't key, the first click just activates the window.
        // Re-send it so SwiftUI controls (tabs, buttons) process the click too.
        if !wasKey && event.type == .leftMouseDown {
            super.sendEvent(event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "s" {
            sessionStore.createCheckpointForActiveSession()
            return true
        }
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "t" {
            sessionStore.createQuickSession()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
