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
    
    var body: some View {
        ZStack {
            if sessionStore.activeTab == .terminal {
                terminalLayout
            } else {
                settingsLayout
            }
        }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .clipShape(ClassicPanelShape(cornerRadius: 20))
        .overlay(
            ClassicPanelShape(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var terminalLayout: some View {
        VStack(spacing: 0) {

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
    
    private var settingsContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Settings")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)
                
                SettingsSection(title: "General") {
                    SettingToggleRow(title: "Show notch overlay", description: "Display the Hap overlay above the terminal panel.", isOn: $settings.showNotch)
                        .onChange(of: settings.showNotch) {
                            NotificationCenter.default.post(name: .NotchySettingsChanged, object: nil)
                        }
                    SettingToggleRow(title: "Reveal panel on hover", description: "Automatically open the terminal panel when hovering over the notch.", isOn: $settings.revealOnHover)
                    SettingToggleRow(title: "Enable sounds", description: "Play subtle sound effects for Claude task completion.", isOn: $settings.soundsEnabled)
                }
                
                SettingsSection(title: "Integrations") {
                    SettingToggleRow(title: "Claude status updates", description: "Shows real-time status updates.", isOn: $settings.claudeIntegrationEnabled)
                }

                SettingsSection(title: "About") {
                    VStack(spacing: 12) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .frame(width: 48, height: 48)
                        Text("Safran Notch")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Text("by Berk Safran")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                        Button("github.com/berksafran") {
                            if let url = URL(string: "https://github.com/berksafran") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
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
                    .foregroundColor(.white.opacity(0.7))
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
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)

                Spacer()

                Button(action: {
                    SessionStore.shared.activeTab = .settings
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
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

#Preview("Panel & NotchBar") {
    VStack(spacing: 30) {
        VStack {
            Text("Notch Bar").foregroundColor(.secondary)
            NotchBar().frame(width: 450)
        }
        
        VStack {
            PanelContentView(
                sessionStore: SessionStore.shared,
                onClose: {}
            )
            .frame(width: 450, height: 600)
        }
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
}
