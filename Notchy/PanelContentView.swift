import SwiftUI
import AppKit

enum PanelTab {
    case terminal
    case settings
}

struct PanelContentView: View {
    @Bindable var sessionStore: SessionStore
    var onClose: () -> Void
    
    @State private var activeTab: PanelTab = .terminal
    @State private var showRestoreConfirmation = false
    @Bindable private var settings = SettingsManager.shared

    private var isUnified: Bool { false } // Unified layout removed; classic and expanded both use ClassicPanelShape

    var body: some View {
        ZStack {
            if sessionStore.activeTab == .terminal {
                terminalLayout
            } else {
                settingsLayout
            }
        }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .clipShape(isUnified ? AnyShape(UnifiedPanelShape(cornerRadius: 20)) : AnyShape(ClassicPanelShape(cornerRadius: 20)))
        .overlay(
            Group {
                if isUnified {
                    UnifiedPanelShape(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                } else {
                    ClassicPanelShape(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                }
            }
        )
    }

    private var terminalLayout: some View {
        VStack(spacing: 0) {
            // MARK: - Notch Bar (Unified layout only)
            if isUnified {
                NotchBar()
            }

            // MARK: - Header (Modern Tab Bar)
            HStack(spacing: 20) {
                ScrollView(.horizontal, showsIndicators: false) {
                    SessionTabBar(sessionStore: sessionStore)
                        .padding(.vertical, 4)
                }

                Spacer(minLength: 0)

                // Actions
                HStack(spacing: 12) {
                    Button(action: { sessionStore.createQuickSession() }) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("New session")
                    
                    Button(action: { sessionStore.isPinned.toggle() }) {
                        Image(systemName: sessionStore.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(sessionStore.isPinned ? .green : .white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help(sessionStore.isPinned ? "Unpin panel" : "Pin panel")
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(Color.black)
            
            // Border Bottom
            Color.black
                .frame(height: 1)

            // MARK: - Content Area
            ZStack {
                terminalContentView
            }
            .padding(.top, 6)
            .padding(.bottom, 4)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
    }

    private var settingsLayout: some View {
        VStack(spacing: 0) {
            if isUnified {
                NotchBar()
            }
            ZStack {
                Color.black
                settingsContentView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Subviews
    
    private var terminalContentView: some View {
        VStack(spacing: 0) {
            if sessionStore.isTerminalExpanded {
                if let session = sessionStore.activeSession {
                    if session.hasStarted {
                        TerminalSessionView(
                            sessionId: session.id,
                            workingDirectory: session.workingDirectory,
                            launchClaude: session.projectPath != nil,
                            generation: session.generation
                        )
                    } else {
                        placeholderView("Click to start session")
                            .onTapGesture {
                                sessionStore.startSessionIfNeeded(session.id)
                            }
                    }
                } else {
                    placeholderView("No active sessions")
                }
            }
        }
    }
    
    private var settingsContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Settings")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)
                
                SettingsSection(title: "General") {
                    SettingLayoutRow(layoutStyle: $settings.layoutStyle)
                    SettingToggleRow(title: "Show notch overlay", description: "Display the Hap overlay above the terminal panel.", isOn: $settings.showNotch)
                    SettingToggleRow(title: "Reveal panel on hover", description: "Automatically open the terminal panel when hovering over the notch.", isOn: $settings.revealOnHover)
                    SettingToggleRow(title: "Enable sounds", description: "Play subtle sound effects for Claude task completion.", isOn: $settings.soundsEnabled)
                }
                
                SettingsSection(title: "Integrations") {
                    SettingToggleRow(title: "Xcode detection", description: "Automatically detect active Xcode projects and open sessions.", isOn: $settings.xcodeIntegrationEnabled)
                    SettingToggleRow(title: "Claude status updates", description: "Show visual indicators when Claude is working or waiting.", isOn: $settings.claudeIntegrationEnabled)
                }
            }
            .padding(32)
        }
    }

    private func placeholderView(_ message: String) -> some View {
        VStack {
            Text(message)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Helper Views

struct SettingLayoutRow: View {
    @Binding var layoutStyle: LayoutStyle

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Panel layout")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Text("Classic: small Hap. Expanded: Hap always matches panel width.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker("", selection: $layoutStyle) {
                Text("Classic").tag(LayoutStyle.classic)
                Text("Expanded").tag(LayoutStyle.expanded)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
        }
        .padding(.vertical, 4)
    }
}

struct SettingToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .padding(.leading, 4)
            
            VStack(spacing: 12) {
                content
            }
            .padding(20)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

// MARK: - Notch Bar (Unified layout)

/// Top bar shown in unified layout mode. Occupies the same vertical space as the physical
/// notch and displays action buttons on either side of the notch gap.
struct NotchBar: View {
    var body: some View {
        let notchHeight = Self.computeNotchHeight()
        ZStack {
            Color.black
            HStack {
                Button(action: {
                    SessionStore.shared.activeTab = .terminal
                }) {
                    Image(systemName: "apple.terminal")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)

                Spacer()

                Button(action: {
                    SessionStore.shared.activeTab = .settings
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
            }
        }
        .frame(height: notchHeight)
    }

    static func computeNotchHeight() -> CGFloat {
        guard let screen = NSScreen.builtIn else { return 37 }
        if #available(macOS 12.0, *),
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            return screen.frame.maxY - min(left.minY, right.minY)
        }
        return screen.frame.maxY - screen.visibleFrame.maxY
    }
}

// MARK: - Panel clip shapes

/// Sharp top corners, rounded bottom corners — used for classic layout where the Hap sits
/// flush on top of the panel. The Hap's bottom edge is flat so the panel's top must be square.
struct ClassicPanelShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = cornerRadius
        var path = Path()
        // Top-left: sharp
        path.move(to: CGPoint(x: 0, y: 0))
        // Top-right: sharp
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        // Bottom-right: rounded
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - r))
        path.addArc(
            center: CGPoint(x: rect.width - r, y: rect.height - r),
            radius: r,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        // Bottom-left: rounded
        path.addLine(to: CGPoint(x: r, y: rect.height))
        path.addArc(
            center: CGPoint(x: r, y: rect.height - r),
            radius: r,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        return path
    }
}

/// Rounded bottom corners only — used for unified layout where the top edge
/// is flush with the screen top and needs no corner rounding.
struct UnifiedPanelShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = cornerRadius
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - r))
        path.addArc(
            center: CGPoint(x: rect.width - r, y: rect.height - r),
            radius: r,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: r, y: rect.height))
        path.addArc(
            center: CGPoint(x: r, y: rect.height - r),
            radius: r,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        return path
    }
}

// MARK: - Type-erasure helper

struct AnyShape: Shape {
    private let _path: @Sendable (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        _path = { shape.path(in: $0) }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
